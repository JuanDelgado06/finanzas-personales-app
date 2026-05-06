import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/monthly_budget.dart';
import '../theme/app_theme.dart';

class SavedBudgetsScreen extends StatefulWidget {
  const SavedBudgetsScreen({super.key});

  @override
  State<SavedBudgetsScreen> createState() => _SavedBudgetsScreenState();
}

class _SavedBudgetsScreenState extends State<SavedBudgetsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadBudgets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: kAppBg,
      body: state.loadingBudgets
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : state.savedBudgets.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
              color: kAccent,
              backgroundColor: kSurface,
              onRefresh: () => context.read<AppState>().loadBudgets(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.savedBudgets.length,
                itemBuilder: (context, index) {
                  return _BudgetCard(
                    budget: state.savedBudgets[index],
                    onDelete: () => _confirmDelete(
                      context,
                      state,
                      state.savedBudgets[index],
                    ),
                    onLoad: () =>
                        _loadBudget(context, state, state.savedBudgets[index]),
                  );
                },
              ),
            ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    AppState state,
    MonthlyBudget budget,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text(
          'Eliminar presupuesto',
          style: TextStyle(color: kTextMain),
        ),
        content: Text(
          '¿Eliminar "${budget.monthName}"?',
          style: const TextStyle(color: kTextSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: kTextSoft)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (budget.monthSlug == null || budget.monthSlug!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Error: el presupuesto no tiene identificador',
                    ),
                    backgroundColor: kDanger,
                  ),
                );
                return;
              }
              final ok = await state.deleteBudget(budget.monthSlug!);
              if (!context.mounted) return;
              final queued = state.hasPendingSync;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? (queued
                              ? 'Eliminado local. Pendiente de sincronizar'
                              : 'Presupuesto eliminado')
                        : 'Error al eliminar',
                  ),
                  backgroundColor: ok ? (queued ? kAccent : kSuccess) : kDanger,
                ),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: kDanger)),
          ),
        ],
      ),
    );
  }

  void _loadBudget(BuildContext context, AppState state, MonthlyBudget budget) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text(
          'Cargar presupuesto',
          style: TextStyle(color: kTextMain),
        ),
        content: Text(
          'Cargar "${budget.monthName}" reemplazará el formulario actual.',
          style: const TextStyle(color: kTextSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: kTextSoft)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _applyBudget(state, budget);
            },
            child: const Text('Cargar', style: TextStyle(color: kAccent)),
          ),
        ],
      ),
    );
  }

  void _applyBudget(AppState state, MonthlyBudget budget) {
    state.monthName = budget.monthName;
    state.assets = List.from(budget.assets);
    state.owed = List.from(budget.owed);
    state.liabilities = List.from(budget.liabilities);
    state.microExpenses = List.from(budget.microExpenses);
    if (budget.microExpenseCategories.isNotEmpty) {
      state.microExpenseCategories = List.from(budget.microExpenseCategories);
    }
    state.notifyListeners();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Presupuesto cargado'),
        backgroundColor: kSuccess,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PhosphorIcon(
            PhosphorIconsLight.folderOpen,
            color: kTextSoft.withOpacity(0.4),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Sin presupuestos guardados',
            style: TextStyle(color: kTextSoft, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Guarda un presupuesto desde la pestaña principal',
            style: TextStyle(color: kTextSoft, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final MonthlyBudget budget;
  final VoidCallback onDelete;
  final VoidCallback onLoad;
  const _BudgetCard({
    required this.budget,
    required this.onDelete,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = budget.netWorth >= 0;
    final date = _formatDate(budget.createdAt);
    return GestureDetector(
      onTap: onLoad,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(
          borderColor: isPositive
              ? kSuccess.withOpacity(0.25)
              : kDanger.withOpacity(0.25),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.monthName.isEmpty
                            ? 'Sin nombre'
                            : budget.monthName,
                        style: const TextStyle(
                          color: kTextMain,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (date != null)
                        Text(
                          date,
                          style: const TextStyle(
                            color: kTextSoft,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCurrencyFull(budget.netWorth),
                      style: TextStyle(
                        color: isPositive ? kSuccess : kDanger,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      'balance neto',
                      style: TextStyle(color: kTextSoft, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: kDanger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const PhosphorIcon(
                      PhosphorIconsLight.trash,
                      color: kDanger,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip('Activos', budget.totalAssets, kSuccess),
                const SizedBox(width: 8),
                _StatChip('Gastos', budget.totalLiabilities, kDanger),
                const SizedBox(width: 8),
                _StatChip(
                  'Hormiga',
                  budget.microExpenses.fold(0.0, (s, m) => s + m.amount),
                  kWarning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _formatDate(String? iso) {
    if (iso == null) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return null;
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              formatCurrency(value),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(label, style: const TextStyle(color: kTextSoft, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
