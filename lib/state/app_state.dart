import 'package:flutter/foundation.dart';
import '../models/budget_item.dart';
import '../models/monthly_budget.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

const List<String> kDefaultCategories = [
  'General', 'Comida', 'Transporte', 'Cafe', 'Snacks', 'Antojos',
  'Mercado rapido', 'Apps', 'Streaming', 'Hogar', 'Salud',
  'Mascotas', 'Regalos', 'Otros'
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

  AppState({required this.authService}) {
    apiService = ApiService(getIdToken: authService.getIdToken);
    _resetForm();
  }

  // ── Calculated totals ──────────────────────────────────────────────────────
  double get totalAssets =>
      [...assets, ...owed].fold(0, (sum, i) => sum + i.amount);

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

  double get totalLiabilities => totalLiabilitiesWithoutMicro + totalMicroExpenses;
  double get partialLiabilities => partialLiabilitiesWithoutMicro + totalMicroExpenses;
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

  void updateMicroExpense(int index, {double? amount, String? category, String? paymentMethod}) {
    if (amount != null) microExpenses[index].amount = amount;
    if (category != null) microExpenses[index].category = category;
    if (paymentMethod != null) microExpenses[index].paymentMethod = paymentMethod;
    notifyListeners();
  }

  void removeMicroExpense(int index) { microExpenses.removeAt(index); notifyListeners(); }

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

  Future<bool> deleteBudget(String id) async {
    try {
      await apiService.deleteBudget(id);
      savedBudgets.removeWhere((b) => b.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting budget: $e');
      return false;
    }
  }
}
