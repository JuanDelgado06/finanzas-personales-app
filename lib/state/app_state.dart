import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/budget_item.dart';
import '../models/monthly_budget.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

const List<String> kDefaultCategories = [
  'Comida', 'Transporte', 'Mercado', 'Salud', 'Hogar', 'Otros'
];

class AppState extends ChangeNotifier {
  final AuthService authService;
  late final ApiService apiService;

  // Form state
  String monthName = '';
  List<BudgetItem> assets = [];
  List<BudgetItem> owed = [];
  List<dynamic> liabilities = []; // Liability | CreditCard
  List<MicroExpense> microExpenses = [];
  List<String> microExpenseCategories = List.from(kDefaultCategories);

  // Saved budgets
  List<MonthlyBudget> savedBudgets = [];
  bool loadingBudgets = false;

  // Auto-save state
  bool isSaving = false;
  bool lastSaveOk = true;
  Timer? _saveDebounce;

  AppState({required this.authService}) {
    apiService = ApiService(getIdToken: authService.getIdToken);
    _resetForm();
  }

  // ── Calculated totals ──────────────────────────────────────────────────────
  double get _baseAssets =>
      [...assets, ...owed].fold(0, (sum, i) => sum + i.amount);

  String _normalizePaymentMethod(String value) => value.trim().toLowerCase();

  Map<String, double> get availableAmountByItemId {
    final remainingById = <String, double>{};
    final itemsByMethod = <String, List<BudgetItem>>{};

    for (final item in [...assets, ...owed]) {
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
        final applied = remainingExpense <= available ? remainingExpense : available;
        remainingById[item.id] = available - applied;
        remainingExpense -= applied;
      }
    }

    return remainingById;
  }

  double get _microExpensesCoveredByAssets {
    final remainingTotal = availableAmountByItemId.values.fold(0.0, (sum, value) => sum + value);
    final covered = _baseAssets - remainingTotal;
    return covered > 0 ? covered : 0;
  }

  double get _uncoveredMicroExpenses {
    final remaining = totalMicroExpenses - _microExpensesCoveredByAssets;
    return remaining > 0 ? remaining : 0;
  }

  double get totalAssets =>
      availableAmountByItemId.values.fold(0.0, (sum, value) => sum + value);

  double get totalMicroExpenses =>
      microExpenses.fold(0, (sum, m) => sum + m.amount);

  double get totalLiabilitiesWithoutMicro => liabilities.fold(0, (sum, l) {
        if (l is CreditCard) return sum + l.total;
        if (l is Liability) return sum + l.amount;
        return sum;
      });

  double get partialLiabilitiesWithoutMicro => liabilities.fold(0, (sum, l) {
        if (l is CreditCard) return sum + l.minimum;
        if (l is Liability) return sum + l.amount;
        return sum;
      });

  double get totalLiabilities => totalLiabilitiesWithoutMicro + _uncoveredMicroExpenses;
  double get partialLiabilities => partialLiabilitiesWithoutMicro + _uncoveredMicroExpenses;
  double get netWorth => totalAssets - totalLiabilities;
  double get partialNetWorth => totalAssets - partialLiabilities;
  double get savingsGoal => totalAssets - partialLiabilities;

  List<String> get assetNames =>
      [...assets, ...owed].map((a) => a.name.trim()).where((n) => n.isNotEmpty).toList();

  // ── Form actions ───────────────────────────────────────────────────────────
  void _resetForm() {
    monthName = '';
    microExpenseCategories = List.from(kDefaultCategories);
    assets = [
      BudgetItem(id: '1', name: 'Nequi', amount: 0),
      BudgetItem(id: '2', name: 'Uala', amount: 0),
      BudgetItem(id: '3', name: 'Davivienda', amount: 0),
      BudgetItem(id: '4', name: 'Efectivo', amount: 0),
    ];
    owed = [BudgetItem(id: '5', name: 'Me deben', amount: 0)];
    liabilities = [
      CreditCard(id: '6', name: 'Tarjeta N', total: 0, minimum: 0),
      CreditCard(id: '7', name: 'Tarjeta V', total: 0, minimum: 0),
      Liability(id: '8', name: 'Moto', amount: 0),
      Liability(id: '9', name: 'Arriendo', amount: 0),
      Liability(id: '10', name: 'Servicios', amount: 0),
      Liability(id: '11', name: 'Mercado', amount: 0),
    ];
    microExpenses = [];
  }

  void resetForm() {
    _resetForm();
    notifyListeners();
  }

  void updateAsset(int index, {String? name, double? amount}) {
    if (name != null) assets[index].name = name;
    if (amount != null) assets[index].amount = amount;
    notifyListeners();
  }

  void addAsset() {
    assets.add(BudgetItem(id: DateTime.now().millisecondsSinceEpoch.toString(), name: '', amount: 0));
    notifyListeners();
  }

  void removeAsset(int index) { assets.removeAt(index); notifyListeners(); }

  void updateOwed(int index, {String? name, double? amount}) {
    if (name != null) owed[index].name = name;
    if (amount != null) owed[index].amount = amount;
    notifyListeners();
  }

  void addOwed() {
    owed.add(BudgetItem(id: DateTime.now().millisecondsSinceEpoch.toString(), name: '', amount: 0));
    notifyListeners();
  }

  void removeOwed(int index) { owed.removeAt(index); notifyListeners(); }

  void addLiability() {
    liabilities.add(Liability(id: DateTime.now().millisecondsSinceEpoch.toString(), name: '', amount: 0));
    notifyListeners();
  }

  void addCreditCard() {
    liabilities.add(CreditCard(id: DateTime.now().millisecondsSinceEpoch.toString(), name: '', total: 0, minimum: 0));
    notifyListeners();
  }

  void removeLiability(int index) { liabilities.removeAt(index); notifyListeners(); }

  void addMicroExpense() {
    final defaultPayment = assetNames.isNotEmpty ? assetNames.first : '';
    microExpenses.add(MicroExpense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: 0,
      category: microExpenseCategories.isNotEmpty ? microExpenseCategories.first : 'General',
      paymentMethod: defaultPayment,
    ));
    notifyListeners();
  }

  void addMicroExpenseDirect({
    required double amount,
    required String category,
    required String paymentMethod,
  }) {
    microExpenses.add(MicroExpense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      category: category,
      paymentMethod: paymentMethod,
    ));
    notifyListeners();
    _scheduleSave();
  }

  void updateMicroExpenseDirect(int index, {
    required double amount,
    required String category,
    required String paymentMethod,
  }) {
    microExpenses[index].amount = amount;
    microExpenses[index].category = category;
    microExpenses[index].paymentMethod = paymentMethod;
    notifyListeners();
    _scheduleSave();
  }

  void updateMicroExpense(int index, {double? amount, String? category, String? paymentMethod}) {
    if (amount != null) microExpenses[index].amount = amount;
    if (category != null) microExpenses[index].category = category;
    if (paymentMethod != null) microExpenses[index].paymentMethod = paymentMethod;
    notifyListeners();
  }

  void removeMicroExpense(int index) {
    microExpenses.removeAt(index);
    notifyListeners();
    _scheduleSave();
  }

  // ── Auto-save helpers ─────────────────────────────────────────────────────
  static final _monthFormatter = DateFormat('MMMM yyyy', 'es_CO');

  String get _currentMonthName {
    final now = DateTime.now();
    final raw = _monthFormatter.format(now);
    return raw[0].toUpperCase() + raw.substring(1);
  }

  void _ensureMonthName() {
    if (monthName.trim().isEmpty) {
      monthName = _currentMonthName;
      notifyListeners();
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), _autoSave);
  }

  Future<void> _autoSave() async {
    _ensureMonthName();
    isSaving = true;
    notifyListeners();
    try {
      await apiService.saveBudget(MonthlyBudget(
        monthName: monthName,
        assets: assets,
        owed: owed,
        liabilities: liabilities,
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
      ));
      lastSaveOk = true;
      apiService.getBudgets().then((list) {
        savedBudgets = list;
        notifyListeners();
      }).catchError((_) {});
    } catch (e) {
      debugPrint('Auto-save error: $e');
      lastSaveOk = false;
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

  void removeCategory(String name) {
    microExpenseCategories.remove(name);
    notifyListeners();
  }

  // ── Apply a saved budget into the active form ─────────────────────────────
  void applyBudget(MonthlyBudget budget) {
    monthName = budget.monthName;
    assets = List.from(budget.assets);
    owed = List.from(budget.owed);
    liabilities = List.from(budget.liabilities);
    microExpenses = List.from(budget.microExpenses);
    if (budget.microExpenseCategories.isNotEmpty) {
      microExpenseCategories = List.from(budget.microExpenseCategories);
    }
    notifyListeners();
  }

  // ── API ───────────────────────────────────────────────────────────────────
  Future<void> loadBudgets() async {
    loadingBudgets = true;
    notifyListeners();
    try {
      savedBudgets = await apiService.getBudgets();
    } catch (e) {
      debugPrint('Error loading budgets: $e');
    } finally {
      loadingBudgets = false;
      notifyListeners();
    }
  }

  /// Carga los presupuestos y aplica automáticamente el más reciente.
  Future<void> loadAndAutoApply() async {
    await loadBudgets();
    if (savedBudgets.isEmpty) return;
    // Ordenar por createdAt descendente y tomar el primero
    final sorted = List<MonthlyBudget>.from(savedBudgets)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    applyBudget(sorted.first);
  }

  Future<bool> saveBudget() async {
    final budget = MonthlyBudget(
      monthName: monthName,
      assets: assets,
      owed: owed,
      liabilities: liabilities,
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
      await loadBudgets();
      return true;
    } catch (e) {
      debugPrint('Error saving budget: $e');
      return false;
    }
  }

  Future<bool> deleteBudget(String monthSlug) async {
    try {
      await apiService.deleteBudget(monthSlug);
      savedBudgets.removeWhere((b) => b.monthSlug == monthSlug);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting budget: $e');
      return false;
    }
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
}
