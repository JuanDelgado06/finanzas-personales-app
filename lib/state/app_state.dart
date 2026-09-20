import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget_item.dart';
import '../models/monthly_budget.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

const List<String> kDefaultCategories = [
  'Comida',
  'Transporte',
  'Mercado',
  'Salud',
  'Hogar',
  'Otros',
];

class AppState extends ChangeNotifier {
  final AuthService authService;
  late final ApiService apiService;

  // Form state
  static const String _budgetsCacheKeyPrefix = 'saved_budgets_cache_v1';
  static const String _pendingOpsCacheKeyPrefix = 'pending_budget_ops_v1';
  static const String _draftCacheKeyPrefix = 'budget_draft_v1';
  bool _syncingPendingOps = false;
  int _pendingOpsCount = 0;
  bool _hasUnsavedBudgetChanges = false;

  String monthName = '';
  DateTime selectedBudgetDate = DateTime.now();
  List<BudgetItem> assets = [];
  List<BudgetItem> owed = [];
  List<dynamic> liabilities = []; // only Liability
  List<CreditCard> creditCards = [
    CreditCard(
      id: '6',
      name: 'Tarjeta N',
      creditLimit: 0,
      balance: 0,
      minimum: 0,
      paymentTotal: 0,
    ),
  ];
  List<MicroExpense> microExpenses = [];
  List<String> microExpenseCategories = List.from(kDefaultCategories);

  // Saved budgets
  List<MonthlyBudget> savedBudgets = [];
  bool loadingBudgets = false;
  bool isLoadingMonth = false; // Indicador para el cargamento inicial del mes
  bool _reportedServerMisconfiguration = false;

  bool get isSyncingPendingOps => _syncingPendingOps;
  bool get hasPendingSync => _pendingOpsCount > 0;
  int get pendingOpsCount => _pendingOpsCount;
  bool get hasUnsavedBudgetChanges => _hasUnsavedBudgetChanges;

  String get _userCacheKey {
    final uid = authService.currentUser?.uid;
    return uid == null || uid.isEmpty ? 'anonymous' : uid;
  }

  String get _budgetsCacheKey => '$_budgetsCacheKeyPrefix:$_userCacheKey';

  String get _pendingOpsCacheKey => '$_pendingOpsCacheKeyPrefix:$_userCacheKey';

  String get _draftCacheKey => '$_draftCacheKeyPrefix:$_userCacheKey';

  // Auto-save state
  bool isSaving = false;
  bool lastSaveOk = true;
  String? lastSaveError;
  Timer? _saveDebounce;

  AppState({required this.authService}) {
    apiService = ApiService(
      getIdToken: () => authService.getIdToken(forceRefresh: true),
    );
    _resetForm();
    _initPendingOpsState();
  }

  Future<void> _initPendingOpsState() async {
    final ops = await _readPendingOpsCache();
    _pendingOpsCount = ops.length;
    notifyListeners();
  }

  // ── Calculated totals ──────────────────────────────────────────────────────
  double get _baseAssets => assets.fold(0, (sum, i) => sum + i.amount);

  String _normalizePaymentMethod(String value) => value.trim().toLowerCase();

  CreditCard? _findCreditCardByPaymentMethod(String paymentMethod) {
    final key = _normalizePaymentMethod(paymentMethod);
    if (key.isEmpty) return null;
    for (final card in creditCards) {
      if (_normalizePaymentMethod(card.name) == key) return card;
    }
    return null;
  }

  void _applyCreditCardChargeDelta({
    required String paymentMethod,
    required double deltaAmount,
  }) {
    if (deltaAmount == 0) return;
    final card = _findCreditCardByPaymentMethod(paymentMethod);
    if (card == null) return;

    final nextTotal = card.paymentTotal + deltaAmount;
    card.paymentTotal = nextTotal > 0 ? nextTotal : 0;
    final nextBalance = card.creditLimit - card.paymentTotal;
    card.balance = nextBalance > 0 ? nextBalance : 0;
  }

  Map<String, double> get availableAmountByItemId {
    final remainingById = <String, double>{};
    final itemsByMethod = <String, List<BudgetItem>>{};

    for (final item in assets) {
      remainingById[item.id] = item.amount;
      final key = _normalizePaymentMethod(item.name);
      if (key.isEmpty) continue;
      itemsByMethod.putIfAbsent(key, () => <BudgetItem>[]).add(item);
    }

    for (final expense in microExpenses) {
      final key = _normalizePaymentMethod(expense.paymentMethod);
      if (key.isEmpty) continue;
      final bucket = itemsByMethod[key];
      if (bucket == null || bucket.isEmpty) continue;

      var remainingExpense = expense.amount;
      for (final item in bucket) {
        if (remainingExpense <= 0) break;
        final available = remainingById[item.id] ?? 0;
        if (available <= 0) continue;
        final applied = remainingExpense <= available
            ? remainingExpense
            : available;
        remainingById[item.id] = available - applied;
        remainingExpense -= applied;
      }
      // Si el gasto supera lo disponible, el excedente se refleja como saldo
      // negativo en el último activo con ese nombre (p. ej. efectivo de 50,000
      // y gasto de 51,000 → -1,000) en vez de quedarse en 0. Así el excedente
      // ya está descontado de los activos y no se cuenta otra vez como pasivo
      // en _uncoveredMicroExpenses.
      if (remainingExpense > 0) {
        final last = bucket.last;
        remainingById[last.id] =
            (remainingById[last.id] ?? 0) - remainingExpense;
      }
    }

    return remainingById;
  }

  double get _microExpensesCoveredByAssets {
    final remainingTotal = availableAmountByItemId.values.fold(
      0.0,
      (sum, value) => sum + value,
    );
    final covered = _baseAssets - remainingTotal;
    return covered > 0 ? covered : 0;
  }

  double get _totalOwed => owed.fold(0.0, (sum, item) => sum + item.amount);

  double get _microExpensesCoveredByCreditCards {
    double total = 0;
    for (final expense in microExpenses) {
      if (_findCreditCardByPaymentMethod(expense.paymentMethod) != null) {
        total += expense.amount;
      }
    }
    return total;
  }

  double get _uncoveredMicroExpenses {
    final remaining =
        totalMicroExpenses -
        _microExpensesCoveredByAssets -
        _microExpensesCoveredByCreditCards;
    return remaining > 0 ? remaining : 0;
  }

  double get totalAssets =>
      availableAmountByItemId.values.fold(0.0, (sum, value) => sum + value) +
      _totalOwed;

  double get totalMicroExpenses =>
      microExpenses.fold(0, (sum, m) => sum + m.amount);

  double get totalLiabilitiesWithoutMicro =>
      liabilities.fold(0.0, (sum, l) {
        if (l is Liability) return sum + l.amount;
        return sum;
      }) +
      creditCards.fold(0.0, (sum, c) => sum + c.paymentTotal);
  double get partialLiabilitiesWithoutMicro =>
      liabilities.fold(0.0, (sum, l) {
        if (l is Liability) return sum + l.amount;
        return sum;
      }) +
      creditCards.fold(0.0, (sum, c) => sum + c.minimum);

  double get totalLiabilities =>
      totalLiabilitiesWithoutMicro + _uncoveredMicroExpenses;
  double get partialLiabilities =>
      partialLiabilitiesWithoutMicro + _uncoveredMicroExpenses;
  double get netWorth => totalAssets - totalLiabilities;
  double get partialNetWorth => totalAssets - partialLiabilities;
  double get savingsGoal => totalAssets - partialLiabilities;
  double get budgetUsagePercent {
    if (totalAssets <= 0) return 0;
    final percent = (totalLiabilities / totalAssets) * 100;
    if (!percent.isFinite) return 0;
    return percent.clamp(0, 999).toDouble();
  }

  MapEntry<String, double>? get topMicroExpenseCategory {
    if (microExpenses.isEmpty) return null;
    final byCategory = <String, double>{};
    for (final m in microExpenses) {
      final key = m.category.trim().isEmpty ? 'General' : m.category.trim();
      byCategory[key] = (byCategory[key] ?? 0) + m.amount;
    }

    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first;
  }

  MapEntry<String, int>? get mostActiveMicroExpenseDay {
    if (microExpenses.isEmpty) return null;

    final countsByDay = <DateTime, int>{};
    for (final expense in microExpenses) {
      final day = DateTime(
        expense.createdAt.year,
        expense.createdAt.month,
        expense.createdAt.day,
      );
      countsByDay[day] = (countsByDay[day] ?? 0) + 1;
    }

    final sortedDays = countsByDay.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return b.key.compareTo(a.key);
      });

    final topDay = sortedDays.first;
    return MapEntry(_formatMicroExpenseDay(topDay.key), topDay.value);
  }

  String _formatMicroExpenseDay(DateTime date) {
    const weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return '${weekdays[date.weekday - 1]} ${date.day}';
  }

  List<String> get assetNames =>
      assets.map((a) => a.name.trim()).where((n) => n.isNotEmpty).toList();

  List<String> get paymentMethodNames {
    final names = <String>[];
    for (final n in assetNames) {
      if (!names.contains(n)) names.add(n);
    }
    for (final c in creditCards) {
      final cardName = c.name.trim();
      if (cardName.isEmpty) continue;
      if (!names.contains(cardName)) names.add(cardName);
    }
    return names;
  }

  // ── Form actions ───────────────────────────────────────────────────────────
  bool _monthNameTaken(String name) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return false;
    return savedBudgets.any((b) => b.monthName.trim().toLowerCase() == key);
  }

  DateTime _addMonths(DateTime date, int months) {
    final totalMonths = date.month - 1 + months;
    return DateTime(date.year + totalMonths ~/ 12, totalMonths % 12 + 1);
  }

  /// Devuelve el primer mes (a partir de hoy) que todavía no tiene un
  /// presupuesto guardado, para que "Nuevo mes" nunca reutilice el nombre de
  /// un mes ya guardado y termine sobrescribiéndolo al autoguardar.
  DateTime _nextAvailableMonthDate() {
    var candidate = DateTime(DateTime.now().year, DateTime.now().month);
    var guard = 0;
    while (_monthNameTaken(formatMonthName(candidate)) && guard < 60) {
      candidate = _addMonths(candidate, 1);
      guard++;
    }
    return candidate;
  }

  void _resetForm() {
    final targetDate = _nextAvailableMonthDate();
    selectedBudgetDate = targetDate;
    monthName = formatMonthName(targetDate);
    _hasUnsavedBudgetChanges = false;
    microExpenseCategories = List.from(kDefaultCategories);
    assets = [
      BudgetItem(id: '1', name: 'Nequi', amount: 0),
      BudgetItem(id: '2', name: 'Uala', amount: 0),
      BudgetItem(id: '3', name: 'Davivienda', amount: 0),
      BudgetItem(id: '4', name: 'Efectivo', amount: 0),
    ];
    owed = [BudgetItem(id: '5', name: 'Me deben', amount: 0)];
    liabilities = [
      Liability(id: '8', name: 'Moto', amount: 0),
      Liability(id: '9', name: 'Arriendo', amount: 0),
      Liability(id: '10', name: 'Servicios', amount: 0),
      Liability(id: '11', name: 'Mercado', amount: 0),
    ];
    creditCards = [
      CreditCard(
        id: '6',
        name: 'Tarjeta N',
        creditLimit: 0,
        balance: 0,
        minimum: 0,
        paymentTotal: 0,
      ),
    ];
    microExpenses = [];
  }

  void resetForm() {
    _resetForm();
    _clearDraftCache();
    notifyListeners();
  }

  static const _monthNamesEs = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  /// Formatea [date] como "Mes yyyy" en español. Si los datos de locale de
  /// `intl` no están inicializados (p. ej. en tests o muy al inicio del
  /// arranque de la app) recurre a una tabla local en vez de lanzar.
  String formatMonthName(DateTime date) {
    try {
      final raw = _monthFormatter.format(DateTime(date.year, date.month));
      return raw[0].toUpperCase() + raw.substring(1);
    } catch (_) {
      return '${_monthNamesEs[date.month - 1]} ${date.year}';
    }
  }

  void setMonthFromDate(DateTime date) {
    selectedBudgetDate = date;
    monthName = formatMonthName(date);
    markBudgetDirty();
  }

  String get selectedDayLabel {
    try {
      return DateFormat('d', 'es_CO').format(selectedBudgetDate);
    } catch (_) {
      return selectedBudgetDate.day.toString();
    }
  }

  void ensureCurrentMonthLoaded({bool notify = true}) {
    if (monthName.trim().isNotEmpty) return;
    selectedBudgetDate = DateTime.now();
    monthName = _currentMonthName;
    if (notify) notifyListeners();
  }

  Future<bool> duplicateFromLatestBudget({String? targetMonthName}) async {
    final target = (targetMonthName ?? monthName).trim();

    if (savedBudgets.isEmpty) {
      await loadBudgets();
    }
    if (savedBudgets.isEmpty) return false;

    final targetKey = target.toLowerCase();
    final sorted = List<MonthlyBudget>.from(savedBudgets)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    MonthlyBudget? source;
    for (final budget in sorted) {
      if (budget.monthName.trim().toLowerCase() != targetKey) {
        source = budget;
        break;
      }
    }

    if (source == null) return false;

    monthName = target.isEmpty ? _currentMonthName : target;
    assets = source.assets.map((a) => BudgetItem.fromJson(a.toJson())).toList();
    owed = source.owed.map((a) => BudgetItem.fromJson(a.toJson())).toList();
    final clonedLiabilities = <dynamic>[];
    for (final l in source.liabilities) {
      if (l is Liability) {
        clonedLiabilities.add(Liability.fromJson(l.toJson()));
        continue;
      }
      if (l is Map) {
        final raw = Map<String, dynamic>.from(l);
        if ((raw['type'] ?? '').toString() == 'credit-card') {
          continue;
        }
        try {
          clonedLiabilities.add(Liability.fromJson(raw));
        } catch (_) {
          // Ignorar liabilities invalidas heredadas de datos antiguos.
        }
      }
    }
    liabilities = clonedLiabilities;
    creditCards = source.creditCards
        .map((c) => CreditCard.fromJson(c.toJson()))
        .toList();
    microExpenses = source.microExpenses
        .map((m) => MicroExpense.fromJson(m.toJson()))
        .toList();
    microExpenseCategories = source.microExpenseCategories.isNotEmpty
        ? List<String>.from(source.microExpenseCategories)
        : List.from(kDefaultCategories);

    _hasUnsavedBudgetChanges = true;
    _writeDraftCache();
    notifyListeners();
    return true;
  }

  void markBudgetDirty({bool notify = true}) {
    _hasUnsavedBudgetChanges = true;
    _writeDraftCache();
    if (notify) notifyListeners();
  }

  void clearBudgetDirty({bool notify = true}) {
    _hasUnsavedBudgetChanges = false;
    if (notify) notifyListeners();
  }

  void updateAsset(int index, {String? name, double? amount}) {
    if (name != null) assets[index].name = name;
    if (amount != null) assets[index].amount = amount;
    markBudgetDirty();
  }

  void addAsset() {
    assets.add(
      BudgetItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '',
        amount: 0,
      ),
    );
    markBudgetDirty();
  }

  void removeAsset(int index) {
    assets.removeAt(index);
    markBudgetDirty();
  }

  void updateOwed(int index, {String? name, double? amount}) {
    if (name != null) owed[index].name = name;
    if (amount != null) owed[index].amount = amount;
    markBudgetDirty();
  }

  void addOwed() {
    owed.add(
      BudgetItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '',
        amount: 0,
      ),
    );
    markBudgetDirty();
  }

  void removeOwed(int index) {
    owed.removeAt(index);
    markBudgetDirty();
  }

  void addLiability() {
    liabilities.add(
      Liability(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '',
        amount: 0,
      ),
    );
    markBudgetDirty();
  }

  void addCreditCard() {
    creditCards.add(
      CreditCard(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '',
        creditLimit: 0,
        balance: 0,
        minimum: 0,
        paymentTotal: 0,
      ),
    );
    markBudgetDirty();
  }

  void removeCreditCard(int index) {
    creditCards.removeAt(index);
    markBudgetDirty();
  }

  String? applyCreditCardPayment({
    required String cardId,
    required String assetName,
    required double amount,
  }) {
    if (amount <= 0) return 'Ingresa un monto valido';

    final cardIndex = creditCards.indexWhere((c) => c.id == cardId);
    if (cardIndex < 0) return 'No se encontro la tarjeta';

    final assetIndex = assets.indexWhere(
      (a) =>
          _normalizePaymentMethod(a.name) == _normalizePaymentMethod(assetName),
    );
    if (assetIndex < 0) return 'No se encontro el activo de pago';

    final card = creditCards[cardIndex];
    if (card.paymentTotal <= 0) return 'La tarjeta no tiene saldo pendiente';
    if (amount > card.paymentTotal) return 'El abono supera el saldo pendiente';

    final asset = assets[assetIndex];
    if (amount > asset.amount) return 'Fondos insuficientes en $assetName';

    asset.amount -= amount;
    card.paymentTotal -= amount;
    if (card.paymentTotal < 0) card.paymentTotal = 0;

    final nextBalance = card.creditLimit - card.paymentTotal;
    card.balance = nextBalance > 0 ? nextBalance : 0;

    markBudgetDirty();
    _scheduleSave();
    return null;
  }

  void removeLiability(int index) {
    liabilities.removeAt(index);
    markBudgetDirty();
  }

  void addMicroExpense() {
    final defaultPayment = assetNames.isNotEmpty ? assetNames.first : '';
    microExpenses.add(
      MicroExpense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: 0,
        category: microExpenseCategories.isNotEmpty
            ? microExpenseCategories.first
            : 'General',
        paymentMethod: defaultPayment,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void addMicroExpenseDirect({
    required double amount,
    required String category,
    required String paymentMethod,
  }) {
    microExpenses.add(
      MicroExpense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        category: category,
        paymentMethod: paymentMethod,
        createdAt: DateTime.now(),
      ),
    );
    _applyCreditCardChargeDelta(
      paymentMethod: paymentMethod,
      deltaAmount: amount,
    );
    notifyListeners();
    _scheduleSave();
  }

  void updateMicroExpenseDirect(
    int index, {
    required double amount,
    required String category,
    required String paymentMethod,
  }) {
    final old = microExpenses[index];
    _applyCreditCardChargeDelta(
      paymentMethod: old.paymentMethod,
      deltaAmount: -old.amount,
    );

    microExpenses[index].amount = amount;
    microExpenses[index].category = category;
    microExpenses[index].paymentMethod = paymentMethod;

    _applyCreditCardChargeDelta(
      paymentMethod: paymentMethod,
      deltaAmount: amount,
    );
    notifyListeners();
    _scheduleSave();
  }

  void updateMicroExpense(
    int index, {
    double? amount,
    String? category,
    String? paymentMethod,
  }) {
    final old = microExpenses[index];
    final oldAmount = old.amount;
    final oldMethod = old.paymentMethod;

    if (amount != null) microExpenses[index].amount = amount;
    if (category != null) microExpenses[index].category = category;
    if (paymentMethod != null) {
      microExpenses[index].paymentMethod = paymentMethod;
    }

    final next = microExpenses[index];
    _applyCreditCardChargeDelta(
      paymentMethod: oldMethod,
      deltaAmount: -oldAmount,
    );
    _applyCreditCardChargeDelta(
      paymentMethod: next.paymentMethod,
      deltaAmount: next.amount,
    );

    notifyListeners();
  }

  void removeMicroExpense(int index) {
    final removed = microExpenses[index];
    _applyCreditCardChargeDelta(
      paymentMethod: removed.paymentMethod,
      deltaAmount: -removed.amount,
    );
    microExpenses.removeAt(index);
    notifyListeners();
    _scheduleSave();
  }

  // ── Auto-save helpers ─────────────────────────────────────────────────────
  static final _monthFormatter = DateFormat('MMMM yyyy', 'es_CO');

  String get _currentMonthName => formatMonthName(DateTime.now());

  void _ensureMonthName() {
    ensureCurrentMonthLoaded();
  }

  void _scheduleSave() {
    _writeDraftCache();
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), _autoSave);
  }

  Future<void> _autoSave() async {
    _ensureMonthName();
    final budget = MonthlyBudget(
      monthName: monthName,
      assets: assets,
      owed: owed,
      liabilities: liabilities,
      creditCards: creditCards,
      microExpenses: microExpenses,
      microExpenseCategories: microExpenseCategories,
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      netWorth: netWorth,
      partialNetWorth: partialNetWorth,
      createdAt: DateTime.now().toIso8601String(),
      authorId: authService.currentUser?.uid,
      authorName: authService.currentUser?.displayName,
      authorEmail: authService.currentUser?.email,
    );

    isSaving = true;
    notifyListeners();
    try {
      await apiService.saveBudget(budget);
      lastSaveOk = true;
      lastSaveError = null;
      await _clearDraftCache();
      await _syncPendingOperations(refreshBudgets: true);
    } catch (e) {
      debugPrint('Auto-save error: $e');
      lastSaveOk = false;
      lastSaveError = e.toString();
      await _enqueuePendingSave(budget);
      _upsertLocalBudget(budget);
      await _writeBudgetsCache(savedBudgets);
      await _clearDraftCache();
      notifyListeners();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  void addCategory(String name) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty && !microExpenseCategories.contains(trimmed)) {
      microExpenseCategories.add(trimmed);
      notifyListeners();
    }
  }

  bool removeCategory(String name) {
    if (microExpenseCategories.length <= 1) return false;
    final removed = microExpenseCategories.remove(name);
    if (removed) {
      notifyListeners();
    }
    return removed;
  }

  // ── Apply a saved budget into the active form ─────────────────────────────
  void applyBudget(MonthlyBudget budget) {
    selectedBudgetDate = DateTime.now();
    monthName = budget.monthName;
    assets = List.from(budget.assets);
    owed = List.from(budget.owed);
    liabilities = List.from(budget.liabilities);
    creditCards = List.from(budget.creditCards);
    microExpenses = List.from(budget.microExpenses);
    if (budget.microExpenseCategories.isNotEmpty) {
      microExpenseCategories = List.from(budget.microExpenseCategories);
    }
    _hasUnsavedBudgetChanges = false;
    _clearDraftCache();
    notifyListeners();
  }

  void duplicateBudgetToCurrentMonth(
    MonthlyBudget budget, {
    String? targetMonthName,
  }) {
    final target = (targetMonthName ?? _currentMonthName).trim();
    selectedBudgetDate = DateTime.now();
    monthName = target.isEmpty ? _currentMonthName : target;
    assets = budget.assets.map((a) => BudgetItem.fromJson(a.toJson())).toList();
    owed = budget.owed.map((a) => BudgetItem.fromJson(a.toJson())).toList();
    final clonedLiabilities = <dynamic>[];
    for (final l in budget.liabilities) {
      if (l is Liability) {
        clonedLiabilities.add(Liability.fromJson(l.toJson()));
        continue;
      }
      if (l is Map) {
        final raw = Map<String, dynamic>.from(l);
        if ((raw['type'] ?? '').toString() == 'credit-card') {
          continue;
        }
        try {
          clonedLiabilities.add(Liability.fromJson(raw));
        } catch (_) {
          // Ignorar liabilities invalidas heredadas de datos antiguos.
        }
      }
    }
    liabilities = clonedLiabilities;
    final clonedCards = <CreditCard>[];
    for (final c in budget.creditCards) {
      try {
        clonedCards.add(CreditCard.fromJson(c.toJson()));
      } catch (_) {
        clonedCards.add(
          CreditCard(
            id: c.id,
            name: c.name,
            creditLimit: c.creditLimit,
            balance: c.balance,
            minimum: c.minimum,
            paymentTotal: c.paymentTotal,
            cutoffDay: c.cutoffDay,
            paymentDay: c.paymentDay,
            type: c.type,
          ),
        );
      }
    }
    creditCards = clonedCards;

    final clonedMicroExpenses = <MicroExpense>[];
    for (final m in budget.microExpenses) {
      try {
        clonedMicroExpenses.add(MicroExpense.fromJson(m.toJson()));
      } catch (_) {
        clonedMicroExpenses.add(
          MicroExpense(
            id: m.id,
            amount: m.amount,
            category: m.category,
            paymentMethod: m.paymentMethod,
            createdAt: m.createdAt,
          ),
        );
      }
    }
    microExpenses = clonedMicroExpenses;
    microExpenseCategories = budget.microExpenseCategories.isNotEmpty
        ? List<String>.from(budget.microExpenseCategories)
        : List.from(kDefaultCategories);

    _hasUnsavedBudgetChanges = true;
    _writeDraftCache();
    notifyListeners();
  }

  // ── API ───────────────────────────────────────────────────────────────────
  Future<void> loadBudgets() async {
    loadingBudgets = true;
    notifyListeners();
    try {
      await _syncPendingOperations(refreshBudgets: false);
      savedBudgets = await apiService.getBudgets();
      _reportedServerMisconfiguration = false;
      await _writeBudgetsCache(savedBudgets);
    } catch (e) {
      final errorText = e.toString();
      if (errorText.contains('server-misconfiguration')) {
        if (!_reportedServerMisconfiguration) {
          debugPrint(
            'Backend con configuracion invalida (server-misconfiguration). '
            'Verifica variables de entorno de Firebase Admin y MongoDB en Vercel.',
          );
          _reportedServerMisconfiguration = true;
        }
      } else {
        debugPrint('Error loading budgets: $e');
      }
      final cached = await _readBudgetsCache();
      if (cached.isNotEmpty) {
        savedBudgets = cached;
      }
    } finally {
      loadingBudgets = false;
      notifyListeners();
    }
  }

  /// Carga los presupuestos y aplica automáticamente el más reciente.
  ///
  /// Si había un borrador local sin guardar (p. ej. la app se cerró antes de
  /// tocar "Guardar" o antes de que el autoguardado con debounce llegara a
  /// disparar), se reaplica encima para no perder esos cambios.
  Future<void> loadAndAutoApply() async {
    isLoadingMonth = true;
    notifyListeners();
    try {
      final draft = await _readDraftCache();
      await loadBudgets();
      if (savedBudgets.isNotEmpty) {
        // Ordenar por createdAt descendente y tomar el primero
        final sorted = List<MonthlyBudget>.from(savedBudgets)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        applyBudget(sorted.first);
      }
      if (draft != null) {
        _applyDraft(draft);
      }
    } finally {
      isLoadingMonth = false;
      notifyListeners();
    }
  }

  void _applyDraft(MonthlyBudget draft) {
    selectedBudgetDate = DateTime.now();
    monthName = draft.monthName;
    assets = List.from(draft.assets);
    owed = List.from(draft.owed);
    liabilities = List.from(draft.liabilities);
    creditCards = List.from(draft.creditCards);
    microExpenses = List.from(draft.microExpenses);
    if (draft.microExpenseCategories.isNotEmpty) {
      microExpenseCategories = List.from(draft.microExpenseCategories);
    }
    _hasUnsavedBudgetChanges = true;
  }

  Future<bool> saveBudget() async {
    final budget = MonthlyBudget(
      monthName: monthName,
      assets: assets,
      owed: owed,
      liabilities: liabilities,
      creditCards: creditCards,
      microExpenses: microExpenses,
      microExpenseCategories: microExpenseCategories,
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      netWorth: netWorth,
      partialNetWorth: partialNetWorth,
      createdAt: DateTime.now().toIso8601String(),
      authorId: authService.currentUser?.uid,
      authorName: authService.currentUser?.displayName,
      authorEmail: authService.currentUser?.email,
    );
    try {
      await apiService.saveBudget(budget);
      await _syncPendingOperations(refreshBudgets: false);
      await loadBudgets();
      lastSaveOk = true;
      lastSaveError = null;
      clearBudgetDirty(notify: false);
      await _clearDraftCache();
      return true;
    } catch (e) {
      debugPrint('Error saving budget: $e');
      lastSaveOk = false;
      lastSaveError = e.toString();
      await _enqueuePendingSave(budget);
      _upsertLocalBudget(budget);
      await _writeBudgetsCache(savedBudgets);
      clearBudgetDirty(notify: false);
      await _clearDraftCache();
      notifyListeners();
      return false;
    }
  }

  /// Elimina [budget] del historial. Si nunca llegó a sincronizarse con el
  /// servidor (no tiene `monthSlug`) solo existe localmente, así que se
  /// borra de la caché y de la cola de sincronización pendiente sin llamar
  /// al backend; de lo contrario se elimina en el servidor (o se encola
  /// para reintentar si falla la red).
  Future<bool> deleteBudget(MonthlyBudget budget) async {
    final monthSlug = budget.monthSlug;
    if (monthSlug == null || monthSlug.isEmpty) {
      await _cancelPendingSaveForMonth(budget.monthName);
      final key = budget.monthName.trim().toLowerCase();
      savedBudgets.removeWhere((b) => b.monthName.trim().toLowerCase() == key);
      await _writeBudgetsCache(savedBudgets);
      notifyListeners();
      return true;
    }

    try {
      await apiService.deleteBudget(monthSlug);
      savedBudgets.removeWhere((b) => b.monthSlug == monthSlug);
      await _syncPendingOperations(refreshBudgets: false);
      await _writeBudgetsCache(savedBudgets);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting budget: $e');
      savedBudgets.removeWhere((b) => b.monthSlug == monthSlug);
      await _enqueuePendingDelete(monthSlug);
      await _writeBudgetsCache(savedBudgets);
      notifyListeners();
      return true;
    }
  }

  Future<void> _cancelPendingSaveForMonth(String monthName) async {
    final ops = await _readPendingOpsCache();
    final monthKey = monthName.trim().toLowerCase();
    ops.removeWhere((op) {
      if (op['type'] != 'save') return false;
      final rawBudget = op['budget'];
      if (rawBudget is! Map) return false;
      final pendingMonth = (rawBudget['monthName'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return pendingMonth == monthKey;
    });
    await _writePendingOpsCache(ops);
  }

  Future<void> _writeBudgetsCache(List<MonthlyBudget> budgets) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = budgets.map((b) => b.toJson()).toList();
      await prefs.setString(_budgetsCacheKey, jsonEncode(payload));
    } catch (e) {
      debugPrint('Error writing budgets cache: $e');
    }
  }

  Future<List<MonthlyBudget>> _readBudgetsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_budgetsCacheKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(MonthlyBudget.fromJson)
          .toList();
    } catch (e) {
      debugPrint('Error reading budgets cache: $e');
      return [];
    }
  }

  /// Instantánea del formulario actual (aún no guardado explícitamente).
  ///
  /// Se escribe en cada edición para que un cierre repentino de la app no
  /// pierda cambios que todavía no pasaron por el botón "Guardar" ni por el
  /// autoguardado con debounce (que depende de red/autenticación).
  MonthlyBudget _currentFormSnapshot() {
    return MonthlyBudget(
      monthName: monthName,
      assets: assets,
      owed: owed,
      liabilities: liabilities,
      creditCards: creditCards,
      microExpenses: microExpenses,
      microExpenseCategories: microExpenseCategories,
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      netWorth: netWorth,
      partialNetWorth: partialNetWorth,
      createdAt: DateTime.now().toIso8601String(),
      authorId: authService.currentUser?.uid,
      authorName: authService.currentUser?.displayName,
      authorEmail: authService.currentUser?.email,
    );
  }

  Future<void> _writeDraftCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _draftCacheKey,
        jsonEncode(_currentFormSnapshot().toJson()),
      );
    } catch (e) {
      debugPrint('Error writing draft cache: $e');
    }
  }

  Future<MonthlyBudget?> _readDraftCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftCacheKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return MonthlyBudget.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      debugPrint('Error reading draft cache: $e');
      return null;
    }
  }

  Future<void> _clearDraftCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftCacheKey);
    } catch (e) {
      debugPrint('Error clearing draft cache: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _readPendingOpsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingOpsCacheKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('Error reading pending ops cache: $e');
      return [];
    }
  }

  Future<void> _writePendingOpsCache(List<Map<String, dynamic>> ops) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingOpsCacheKey, jsonEncode(ops));
      _pendingOpsCount = ops.length;
      notifyListeners();
    } catch (e) {
      debugPrint('Error writing pending ops cache: $e');
    }
  }

  Future<void> _enqueuePendingSave(MonthlyBudget budget) async {
    final ops = await _readPendingOpsCache();
    final monthKey = budget.monthName.trim().toLowerCase();
    ops.removeWhere((op) {
      if (op['type'] != 'save') return false;
      final rawBudget = op['budget'];
      if (rawBudget is! Map) return false;
      final pendingMonth = (rawBudget['monthName'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return pendingMonth == monthKey;
    });
    ops.add({
      'type': 'save',
      'budget': budget.toJson(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _writePendingOpsCache(ops);
  }

  Future<void> _enqueuePendingDelete(String monthSlug) async {
    final ops = await _readPendingOpsCache();
    ops.removeWhere((op) {
      final type = op['type'];
      if (type == 'delete' && op['monthSlug'] == monthSlug) return true;
      if (type != 'save') return false;
      final rawBudget = op['budget'];
      if (rawBudget is! Map) return false;
      return rawBudget['monthSlug'] == monthSlug;
    });
    ops.add({
      'type': 'delete',
      'monthSlug': monthSlug,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _writePendingOpsCache(ops);
  }

  void _upsertLocalBudget(MonthlyBudget budget) {
    final key = budget.monthName.trim().toLowerCase();
    savedBudgets.removeWhere((b) => b.monthName.trim().toLowerCase() == key);
    savedBudgets.insert(0, budget);
  }

  Future<int> _syncPendingOperations({required bool refreshBudgets}) async {
    if (_syncingPendingOps) return 0;

    final ops = await _readPendingOpsCache();
    if (ops.isEmpty) return 0;

    _syncingPendingOps = true;
    notifyListeners();
    var processed = 0;
    try {
      for (final op in ops) {
        final type = (op['type'] ?? '').toString();
        if (type == 'save') {
          final rawBudget = op['budget'];
          if (rawBudget is! Map) {
            processed++;
            continue;
          }
          final budget = MonthlyBudget.fromJson(
            Map<String, dynamic>.from(rawBudget),
          );
          await apiService.saveBudget(budget);
          processed++;
          continue;
        }

        if (type == 'delete') {
          final monthSlug = (op['monthSlug'] ?? '').toString();
          if (monthSlug.isEmpty) {
            processed++;
            continue;
          }
          await apiService.deleteBudget(monthSlug);
          processed++;
          continue;
        }

        processed++;
      }
    } catch (e) {
      debugPrint('Pending sync paused: $e');
    } finally {
      final remaining = processed >= ops.length
          ? <Map<String, dynamic>>[]
          : ops.sublist(processed);
      await _writePendingOpsCache(remaining);
      _syncingPendingOps = false;
      notifyListeners();
    }

    if (refreshBudgets && processed > 0) {
      try {
        savedBudgets = await apiService.getBudgets();
        await _writeBudgetsCache(savedBudgets);
        notifyListeners();
      } catch (e) {
        debugPrint('Error refreshing budgets after pending sync: $e');
      }
    }

    return processed;
  }

  String _budgetMergeKey(MonthlyBudget b) {
    return [
      b.monthName.trim().toLowerCase(),
      b.createdAt,
      b.totalAssets.toStringAsFixed(2),
      b.totalLiabilities.toStringAsFixed(2),
      b.netWorth.toStringAsFixed(2),
      b.partialNetWorth.toStringAsFixed(2),
    ].join('|');
  }

  MonthlyBudget _copyForCurrentUser(MonthlyBudget b) {
    return MonthlyBudget(
      monthName: b.monthName,
      assets: b.assets,
      owed: b.owed,
      liabilities: b.liabilities,
      creditCards: b.creditCards,
      microExpenses: b.microExpenses,
      microExpenseCategories: b.microExpenseCategories,
      totalAssets: b.totalAssets,
      totalLiabilities: b.totalLiabilities,
      netWorth: b.netWorth,
      partialNetWorth: b.partialNetWorth,
      createdAt: b.createdAt,
      authorId: authService.currentUser?.uid,
      authorName: authService.currentUser?.displayName,
      authorEmail: authService.currentUser?.email,
    );
  }

  Future<int> linkAnonymousWithGoogleAndMigrateBudgets() async {
    final wasAnonymous = authService.currentUser?.isAnonymous ?? false;
    List<MonthlyBudget> anonymousBudgets = [];

    if (wasAnonymous) {
      try {
        anonymousBudgets = await apiService.getBudgets();
      } catch (e) {
        debugPrint('No se pudieron cargar presupuestos anonimos: $e');
      }
    }

    await authService.linkAnonymousWithGoogle();

    int migrated = 0;
    if (anonymousBudgets.isNotEmpty) {
      final currentUserBudgets = await apiService.getBudgets();
      final existing = currentUserBudgets.map(_budgetMergeKey).toSet();

      for (final b in anonymousBudgets) {
        final key = _budgetMergeKey(b);
        if (existing.contains(key)) continue;
        try {
          await apiService.saveBudget(_copyForCurrentUser(b));
          existing.add(key);
          migrated++;
        } catch (e) {
          debugPrint('Error migrando presupuesto anonimo: $e');
        }
      }
    }

    await loadBudgets();
    return migrated;
  }

  // ── Share/Import Budget Functions ───────────────────────────────────────────
  String exportBudgetToText(MonthlyBudget budget) {
    final buffer = StringBuffer();
    
    buffer.writeln('=== PRESUPUESTO: ${budget.monthName} ===');
    buffer.writeln('Balance neto: ${formatCurrencyFull(budget.netWorth)}');
    buffer.writeln('');
    
    // Activos
    buffer.writeln('💰 ACTIVOS:');
    for (final asset in budget.assets) {
      if (asset.amount > 0) {
        buffer.writeln('  ${asset.name}: ${formatCurrencyFull(asset.amount)}');
      }
    }
    
    // Me deben
    buffer.writeln('');
    buffer.writeln('📥 ME DEBEN:');
    for (final owed in budget.owed) {
      if (owed.amount > 0) {
        buffer.writeln('  ${owed.name}: ${formatCurrencyFull(owed.amount)}');
      }
    }
    
    // Gastos fijos
    buffer.writeln('');
    buffer.writeln('💸 GASTOS FIJOS:');
    for (final liability in budget.liabilities) {
      if (liability is Liability && liability.amount > 0) {
        buffer.writeln('  ${liability.name}: ${formatCurrencyFull(liability.amount)}');
      }
    }
    
    // Tarjetas de crédito
    buffer.writeln('');
    buffer.writeln('💳 TARJETAS DE CRÉDITO:');
    for (final card in budget.creditCards) {
      if (card.creditLimit > 0 || card.paymentTotal > 0) {
        buffer.writeln('  ${card.name}:');
        buffer.writeln('    Límite: ${formatCurrencyFull(card.creditLimit)}');
        buffer.writeln('    Saldo: ${formatCurrencyFull(card.balance)}');
        buffer.writeln('    Pago total: ${formatCurrencyFull(card.paymentTotal)}');
        buffer.writeln('    Pago mínimo: ${formatCurrencyFull(card.minimum)}');
      }
    }
    
    // Gastos hormiga
    if (budget.microExpenses.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('🐜 GASTOS HORMIGA:');
      for (final expense in budget.microExpenses) {
        if (expense.amount > 0) {
          final dateStr = DateFormat('dd/MM/yyyy').format(expense.createdAt);
          buffer.writeln('  ${dateStr} - ${expense.category}: ${formatCurrencyFull(expense.amount)} (${expense.paymentMethod})');
        }
      }
    }
    
    // Resumen
    buffer.writeln('');
    buffer.writeln('📊 RESUMEN:');
    buffer.writeln('  Total activos: ${formatCurrencyFull(budget.totalAssets)}');
    buffer.writeln('  Total gastos: ${formatCurrencyFull(budget.totalLiabilities)}');
    buffer.writeln('  Balance neto: ${formatCurrencyFull(budget.netWorth)}');
    
    // Footer
    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('Exportado desde Finanzas Personales');
    
    return buffer.toString();
  }

  Future<MonthlyBudget?> importBudgetFromText(String text) async {
    try {
      // Crear un presupuesto básico desde el texto
      // Esta es una implementación simplificada que parsea el formato de texto
      
      final lines = text.split('\n');
      final assets = <BudgetItem>[];
      final owed = <BudgetItem>[];
      final liabilities = <dynamic>[];
      final creditCards = <CreditCard>[];
      final microExpenses = <MicroExpense>[];
      
      String? monthName;
      String currentSection = '';
      
      for (final line in lines) {
        final trimmed = line.trim();
        
        // Detectar sección
        if (trimmed.contains('PRESUPUESTO:')) {
          monthName = trimmed.split('PRESUPUESTO:')[1].trim().replaceAll('===', '').trim();
          continue;
        }
        
        if (trimmed.contains('ACTIVOS:')) {
          currentSection = 'assets';
          continue;
        }
        
        if (trimmed.contains('ME DEBEN:')) {
          currentSection = 'owed';
          continue;
        }
        
        if (trimmed.contains('GASTOS FIJOS:')) {
          currentSection = 'liabilities';
          continue;
        }
        
        if (trimmed.contains('TARJETAS DE CRÉDITO:')) {
          currentSection = 'creditCards';
          continue;
        }
        
        if (trimmed.contains('GASTOS HORMIGA:')) {
          currentSection = 'microExpenses';
          continue;
        }

        if (trimmed.contains('RESUMEN:')) {
          // Cierra cualquier sección anterior para que las líneas del
          // resumen (Total activos, Total gastos, Balance neto) no se
          // interpreten como datos de la última sección vista.
          currentSection = '';
          continue;
        }

        // Parsear líneas según la sección actual
        if (trimmed.isEmpty || trimmed.startsWith('---') || trimmed.contains('RESUMEN') || trimmed.contains('Exportado')) {
          continue;
        }
        
        if (currentSection == 'assets' && trimmed.contains(':')) {
          final parts = trimmed.split(':');
          if (parts.length >= 2) {
            final name = parts[0].trim();
            final amountStr = parts[1].trim().replaceAll('\$', '').replaceAll('.', '').replaceAll(',', '.');
            final amount = double.tryParse(amountStr) ?? 0;
            if (name.isNotEmpty && amount > 0) {
              assets.add(BudgetItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                amount: amount,
              ));
            }
          }
        }
        
        if (currentSection == 'owed' && trimmed.contains(':')) {
          final parts = trimmed.split(':');
          if (parts.length >= 2) {
            final name = parts[0].trim();
            final amountStr = parts[1].trim().replaceAll('\$', '').replaceAll('.', '').replaceAll(',', '.');
            final amount = double.tryParse(amountStr) ?? 0;
            if (name.isNotEmpty && amount > 0) {
              owed.add(BudgetItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                amount: amount,
              ));
            }
          }
        }
        
        if (currentSection == 'liabilities' && trimmed.contains(':')) {
          final parts = trimmed.split(':');
          if (parts.length >= 2) {
            final name = parts[0].trim();
            final amountStr = parts[1].trim().replaceAll('\$', '').replaceAll('.', '').replaceAll(',', '.');
            final amount = double.tryParse(amountStr) ?? 0;
            if (name.isNotEmpty && amount > 0) {
              liabilities.add(Liability(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                amount: amount,
              ));
            }
          }
        }
        
        if (currentSection == 'creditCards' && trimmed.contains(':')) {
          // Formato exportado (exportBudgetToText):
          //   Tarjeta N:
          //     Límite: $x
          //     Saldo: $x
          //     Pago total: $x
          //     Pago mínimo: $x
          final parts = trimmed.split(':');
          final label = parts[0].trim();
          final valueStr = parts.length > 1 ? parts[1].trim() : '';
          const fieldsByLabel = {
            'límite': 'creditLimit',
            'limite': 'creditLimit',
            'saldo': 'balance',
            'pago total': 'paymentTotal',
            'pago mínimo': 'minimum',
            'pago minimo': 'minimum',
          };
          final field = fieldsByLabel[label.toLowerCase()];
          if (field != null && creditCards.isNotEmpty) {
            final amountStr = valueStr
                .replaceAll('\$', '')
                .replaceAll('.', '')
                .replaceAll(',', '.');
            final amount = double.tryParse(amountStr) ?? 0;
            final card = creditCards.last;
            switch (field) {
              case 'creditLimit':
                card.creditLimit = amount;
                break;
              case 'balance':
                card.balance = amount;
                break;
              case 'paymentTotal':
                card.paymentTotal = amount;
                break;
              case 'minimum':
                card.minimum = amount;
                break;
            }
          } else if (field == null && label.isNotEmpty) {
            // Línea con el nombre de la tarjeta (ej: "Tarjeta N:").
            creditCards.add(CreditCard(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: label,
              creditLimit: 0,
              balance: 0,
              minimum: 0,
              paymentTotal: 0,
            ));
          }
        }

        if (currentSection == 'microExpenses' && trimmed.contains('-')) {
          // Formato: "dd/MM/yyyy - Categoria: $cantidad (método)"
          try {
            final parts = trimmed.split('-');
            if (parts.length >= 2) {
              final expensePart = parts[1].trim();
              final expenseParts = expensePart.split(':');
              if (expenseParts.length >= 2) {
                final category = expenseParts[0].trim();
                final amountMethodPart = expenseParts[1].trim();
                final amountMatch = RegExp(r'[\d.,]+').firstMatch(amountMethodPart);
                if (amountMatch != null) {
                  final amountStr = amountMatch.group(0)!.replaceAll('\$', '').replaceAll('.', '').replaceAll(',', '.');
                  final amount = double.tryParse(amountStr) ?? 0;
                  
                  // Extraer método de pago
                  final methodMatch = RegExp(r'\(([^)]+)\)').firstMatch(amountMethodPart);
                  final paymentMethod = methodMatch?.group(1) ?? 'Efectivo';
                  
                  if (category.isNotEmpty && amount > 0) {
                    microExpenses.add(MicroExpense(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      amount: amount,
                      category: category,
                      paymentMethod: paymentMethod,
                      createdAt: DateTime.now(),
                    ));
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error parsing micro expense line: $e');
          }
        }
      }
      
      // Si no se pudo importar nada, retornar null
      if (assets.isEmpty && owed.isEmpty && liabilities.isEmpty && microExpenses.isEmpty) {
        return null;
      }
      
      // Crear el presupuesto importado
      final importedBudget = MonthlyBudget(
        monthName: monthName ?? _currentMonthName,
        assets: assets.isNotEmpty ? assets : [
          BudgetItem(id: '1', name: 'Nequi', amount: 0),
          BudgetItem(id: '2', name: 'Uala', amount: 0),
          BudgetItem(id: '3', name: 'Davivienda', amount: 0),
          BudgetItem(id: '4', name: 'Efectivo', amount: 0),
        ],
        owed: owed.isNotEmpty ? owed : [BudgetItem(id: '5', name: 'Me deben', amount: 0)],
        liabilities: liabilities.isNotEmpty ? liabilities : [
          Liability(id: '8', name: 'Moto', amount: 0),
          Liability(id: '9', name: 'Arriendo', amount: 0),
          Liability(id: '10', name: 'Servicios', amount: 0),
          Liability(id: '11', name: 'Mercado', amount: 0),
        ],
        creditCards: creditCards.isNotEmpty ? creditCards : [
          CreditCard(
            id: '6',
            name: 'Tarjeta N',
            creditLimit: 0,
            balance: 0,
            minimum: 0,
            paymentTotal: 0,
          ),
        ],
        microExpenses: microExpenses,
        microExpenseCategories: List.from(kDefaultCategories),
        totalAssets: assets.fold(0.0, (sum, a) => sum + a.amount) + owed.fold(0.0, (sum, o) => sum + o.amount),
        totalLiabilities: liabilities.fold(0.0, (sum, l) => sum + (l is Liability ? l.amount : 0)) + 
                        creditCards.fold(0.0, (sum, c) => sum + c.paymentTotal) +
                        microExpenses.fold(0.0, (sum, m) => sum + m.amount),
        netWorth: 0, // Se recalculará
        partialNetWorth: 0, // Se recalculará
        createdAt: DateTime.now().toIso8601String(),
        authorId: authService.currentUser?.uid,
        authorName: authService.currentUser?.displayName,
        authorEmail: authService.currentUser?.email,
      );
      
      // Recalcular net worth
      final finalNetWorth = importedBudget.totalAssets - importedBudget.totalLiabilities;
      final finalPartialNetWorth = importedBudget.totalAssets - 
                                   (liabilities.fold(0.0, (sum, l) => sum + (l is Liability ? l.amount : 0)) + 
                                    creditCards.fold(0.0, (sum, c) => sum + c.minimum) +
                                    microExpenses.fold(0.0, (sum, m) => sum + m.amount));
      
      return MonthlyBudget(
        monthName: importedBudget.monthName,
        assets: importedBudget.assets,
        owed: importedBudget.owed,
        liabilities: importedBudget.liabilities,
        creditCards: importedBudget.creditCards,
        microExpenses: importedBudget.microExpenses,
        microExpenseCategories: importedBudget.microExpenseCategories,
        totalAssets: importedBudget.totalAssets,
        totalLiabilities: importedBudget.totalLiabilities,
        netWorth: finalNetWorth,
        partialNetWorth: finalPartialNetWorth,
        createdAt: importedBudget.createdAt,
        authorId: importedBudget.authorId,
        authorName: importedBudget.authorName,
        authorEmail: importedBudget.authorEmail,
      );
      
    } catch (e) {
      debugPrint('Error importing budget from text: $e');
      return null;
    }
  }

  String exportBudgetToJson(MonthlyBudget budget) {
    final exportData = {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'budget': budget.toJson(),
    };
    return jsonEncode(exportData);
  }

  Future<MonthlyBudget?> importBudgetFromJson(String jsonStr) async {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return null;
      
      final budgetData = decoded['budget'];
      if (budgetData is! Map) return null;
      
      final budget = MonthlyBudget.fromJson(Map<String, dynamic>.from(budgetData));
      
      // Asignar el usuario actual como autor
      final importedBudget = MonthlyBudget(
        monthName: budget.monthName,
        assets: budget.assets,
        owed: budget.owed,
        liabilities: budget.liabilities,
        creditCards: budget.creditCards,
        microExpenses: budget.microExpenses,
        microExpenseCategories: budget.microExpenseCategories,
        totalAssets: budget.totalAssets,
        totalLiabilities: budget.totalLiabilities,
        netWorth: budget.netWorth,
        partialNetWorth: budget.partialNetWorth,
        createdAt: DateTime.now().toIso8601String(),
        authorId: authService.currentUser?.uid,
        authorName: authService.currentUser?.displayName,
        authorEmail: authService.currentUser?.email,
      );
      
      return importedBudget;
    } catch (e) {
      debugPrint('Error importing budget from JSON: $e');
      return null;
    }
  }
}
