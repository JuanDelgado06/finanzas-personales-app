import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../models/budget_item.dart';
import '../models/monthly_budget.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Compara dos presupuestos guardados (meses o quincenas) lado a lado:
/// totales principales con su variación y gastos hormiga por categoría.
class CompareBudgetsScreen extends StatefulWidget {
  const CompareBudgetsScreen({super.key});

  @override
  State<CompareBudgetsScreen> createState() => _CompareBudgetsScreenState();
}

class _CompareBudgetsScreenState extends State<CompareBudgetsScreen> {
  MonthlyBudget? _before;
  MonthlyBudget? _after;

  List<MonthlyBudget> _sorted(AppState state) =>
      List<MonthlyBudget>.from(state.savedBudgets)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final budgets = _sorted(state);

    // Por defecto: el más reciente contra el anterior.
    if (budgets.length >= 2) {
      _after ??= budgets[0];
      _before ??= budgets[1];
    }

    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFA050910),
        elevation: 0,
        title: const Text(
          'Comparar presupuestos',
          style: TextStyle(
            color: kTextMain,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      body: budgets.length < 2 || _before == null || _after == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Necesitas al menos dos presupuestos guardados para comparar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextSoft),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _BudgetPicker(
                        label: 'Antes',
                        budget: _before!,
                        onTap: () => _pick(budgets, isBefore: true),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: PhosphorIcon(
                        PhosphorIconsLight.arrowRight,
                        color: kTextSoft,
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: _BudgetPicker(
                        label: 'Después',
                        budget: _after!,
                        onTap: () => _pick(budgets, isBefore: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._metrics(_before!, _after!).map(
                  (m) => _MetricCard(metric: m),
                ),
                const SizedBox(height: 8),
                _CategoryComparison(before: _before!, after: _after!),
              ],
            ),
    );
  }

  Future<void> _pick(List<MonthlyBudget> budgets, {required bool isBefore}) async {
    final current = isBefore ? _before : _after;
    final picked = await showModalBottomSheet<MonthlyBudget>(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: budgets
              .map(
                (b) => ListTile(
                  title: Text(
                    b.monthName,
                    style: const TextStyle(color: kTextMain),
                  ),
                  subtitle: Text(
                    'Balance ${formatCurrencyFull(b.netWorth)}',
                    style: const TextStyle(color: kTextSoft, fontSize: 12),
                  ),
                  trailing: identical(b, current)
                      ? const PhosphorIcon(
                          PhosphorIconsLight.check,
                          color: kAccent,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, b),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isBefore) {
        _before = picked;
      } else {
        _after = picked;
      }
    });
  }
}

class _Metric {
  final String label;
  final double before;
  final double after;

  /// Si subir es bueno (activos, balance) o malo (gastos).
  final bool higherIsBetter;
  const _Metric(this.label, this.before, this.after, {required this.higherIsBetter});
}

double _fixedExpenses(MonthlyBudget b) => b.liabilities.fold(
  0.0,
  (sum, l) => l is Liability ? sum + l.amount : sum,
);

double _cardPayments(MonthlyBudget b) =>
    b.creditCards.fold(0.0, (sum, c) => sum + c.paymentTotal);

double _microTotal(MonthlyBudget b) =>
    b.microExpenses.fold(0.0, (sum, m) => sum + m.amount);

List<_Metric> _metrics(MonthlyBudget a, MonthlyBudget b) => [
  _Metric('Balance neto', a.netWorth, b.netWorth, higherIsBetter: true),
  _Metric('Activos', a.totalAssets, b.totalAssets, higherIsBetter: true),
  _Metric('Gastos fijos', _fixedExpenses(a), _fixedExpenses(b), higherIsBetter: false),
  _Metric('Pago tarjetas', _cardPayments(a), _cardPayments(b), higherIsBetter: false),
  _Metric('Gastos hormiga', _microTotal(a), _microTotal(b), higherIsBetter: false),
  _Metric('Ahorro', a.totalSavings, b.totalSavings, higherIsBetter: true),
];

class _BudgetPicker extends StatelessWidget {
  final String label;
  final MonthlyBudget budget;
  final VoidCallback onTap;
  const _BudgetPicker({
    required this.label,
    required this.budget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: kTextSoft, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    budget.monthName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kTextMain,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const PhosphorIcon(
                  PhosphorIconsLight.caretDown,
                  color: kTextSoft,
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip con la diferencia (en dinero y %) coloreada según si el cambio es
/// bueno o malo para esa métrica.
class _DeltaChip extends StatelessWidget {
  final double before;
  final double after;
  final bool higherIsBetter;
  const _DeltaChip({
    required this.before,
    required this.after,
    required this.higherIsBetter,
  });

  @override
  Widget build(BuildContext context) {
    final delta = after - before;
    if (delta.abs() < 0.5) {
      return const Text(
        'Igual',
        style: TextStyle(color: kTextSoft, fontSize: 11.5),
      );
    }
    final good = (delta > 0) == higherIsBetter;
    final color = good ? kSuccess : kDanger;
    final pct = before.abs() >= 1 ? ' (${(delta / before.abs() * 100).toStringAsFixed(0)}%)' : '';
    final sign = delta > 0 ? '+' : '−';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$sign${formatCurrency(delta.abs())}$pct',
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;
  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  style: const TextStyle(
                    color: kTextMain,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              _DeltaChip(
                before: metric.before,
                after: metric.after,
                higherIsBetter: metric.higherIsBetter,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatCurrencyFull(metric.before),
                  style: const TextStyle(color: kTextSoft, fontSize: 13),
                ),
              ),
              const PhosphorIcon(
                PhosphorIconsLight.arrowRight,
                color: kTextSoft,
                size: 13,
              ),
              Expanded(
                child: Text(
                  formatCurrencyFull(metric.after),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: kTextMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryComparison extends StatelessWidget {
  final MonthlyBudget before;
  final MonthlyBudget after;
  const _CategoryComparison({required this.before, required this.after});

  Map<String, double> _byCategory(MonthlyBudget b) {
    final totals = <String, double>{};
    for (final m in b.microExpenses) {
      final key = m.category.trim().isEmpty ? 'General' : m.category.trim();
      totals[key] = (totals[key] ?? 0) + m.amount;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final a = _byCategory(before);
    final b = _byCategory(after);
    final categories = {...a.keys, ...b.keys}.toList()
      ..sort((x, y) => (b[y] ?? 0).compareTo(b[x] ?? 0));
    if (categories.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gastos hormiga por categoría',
            style: TextStyle(
              color: kTextMain,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          ...categories.map(
            (c) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c,
                          style: const TextStyle(color: kTextMain, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatCurrency(a[c] ?? 0)} → ${formatCurrency(b[c] ?? 0)}',
                          style: const TextStyle(color: kTextSoft, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  _DeltaChip(
                    before: a[c] ?? 0,
                    after: b[c] ?? 0,
                    higherIsBetter: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
