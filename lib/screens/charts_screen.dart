import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ChartsScreen extends StatelessWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Build pie sections for micro expenses by category
    final catTotals = <String, double>{};
    for (final e in state.microExpenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    final sorted = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: kAppBg,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Balance card
          _BalanceCard(state: state),
          const SizedBox(height: 16),
          _KpiHighlightsCard(state: state),
          const SizedBox(height: 16),
          // Insights card
          if (sorted.isNotEmpty) ...[
            _InsightsCard(sorted: sorted, state: state),
            const SizedBox(height: 16),
          ],
          if (sorted.isNotEmpty) ...[
            _ChartSection(
              title: 'Gastos Hormiga por Categoría',
              icon: PhosphorIconsLight.chartPieSlice,
              iconColor: kWarning,
              child: _MicroPieChart(
                data: sorted,
                total: state.totalMicroExpenses,
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Payment method breakdown
          if (state.microExpenses.isNotEmpty) ...[
            _PaymentMethodBreakdown(state: state),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Balance overview ──────────────────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final AppState state;
  const _BalanceCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final rows = [
      _BalRow('Total activos', state.totalAssets, kSuccess),
      _BalRow('Gastos fijos', state.totalLiabilitiesWithoutMicro, kDanger),
      _BalRow('Gastos hormiga', state.totalMicroExpenses, kWarning),
      _BalRow(
        'Pago mínimo total',
        state.partialLiabilitiesWithoutMicro,
        const Color(0xFFF59E0B),
      ),
      _BalRow(
        'Balance neto',
        state.netWorth,
        state.netWorth >= 0 ? kSuccess : kDanger,
        bold: true,
      ),
      _BalRow(
        'Balance parcial',
        state.partialNetWorth,
        state.partialNetWorth >= 0 ? kSuccess : kDanger,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              PhosphorIcon(PhosphorIconsLight.bank, color: kAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'Resumen financiero',
                style: TextStyle(
                  color: kTextMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    r.label,
                    style: TextStyle(
                      color: kTextSoft,
                      fontSize: 13,
                      fontWeight: r.bold ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatCurrencyFull(r.value),
                    style: TextStyle(
                      color: r.color,
                      fontSize: 13,
                      fontWeight: r.bold ? FontWeight.w700 : FontWeight.w500,
                    ),
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

class _BalRow {
  final String label;
  final double value;
  final Color color;
  final bool bold;
  const _BalRow(this.label, this.value, this.color, {this.bold = false});
}

class _KpiHighlightsCard extends StatelessWidget {
  final AppState state;
  const _KpiHighlightsCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final usage = state.budgetUsagePercent;
    final usageColor = usage >= 90
        ? kDanger
        : usage >= 70
        ? kWarning
        : kSuccess;
    final mostActiveDay = state.mostActiveMicroExpenseDay;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(borderColor: kLineSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              PhosphorIcon(PhosphorIconsLight.gauge, color: kAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'Indicadores clave',
                style: TextStyle(
                  color: kTextMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _KpiRow(
            label: 'Uso del presupuesto',
            value: '${usage.toStringAsFixed(0)}%',
            valueColor: usageColor,
          ),
          if (mostActiveDay != null)
            _KpiRow(
              label: 'Día con más gastos registrados',
              value:
                  '${mostActiveDay.key} · ${mostActiveDay.value} ${mostActiveDay.value == 1 ? 'gasto' : 'gastos'}',
              valueColor: kTextMain,
            ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _KpiRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: kTextSoft, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chart section wrapper ─────────────────────────────────────────────────────
class _ChartSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _ChartSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: kTextMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Pie chart ─────────────────────────────────────────────────────────────────
final List<Color> _pieColors = [
  kAccent,
  kWarning,
  kDanger,
  kSuccess,
  const Color(0xFFF59E0B),
  const Color(0xFF14B8A6),
  const Color(0xFFEC4899),
  const Color(0xFF8B5CF6),
  const Color(0xFFEF4444),
  const Color(0xFF10B981),
];

class _MicroPieChart extends StatelessWidget {
  final List<MapEntry<String, double>> data;
  final double total;
  const _MicroPieChart({required this.data, required this.total});

  @override
  Widget build(BuildContext context) {
    final sections = data.asMap().entries.map((e) {
      final color = _pieColors[e.key % _pieColors.length];
      final pct = total > 0 ? (e.value.value / total * 100) : 0;
      return PieChartSectionData(
        value: e.value.value,
        color: color,
        radius: 55,
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        showTitle: pct >= 5,
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: data.asMap().entries.map((e) {
            final color = _pieColors[e.key % _pieColors.length];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${e.value.key} ${formatCurrency(e.value.value)}',
                  style: const TextStyle(color: kTextSoft, fontSize: 11),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Insights card ────────────────────────────────────────────────────────────
class _InsightsCard extends StatelessWidget {
  final List<MapEntry<String, double>> sorted;
  final AppState state;

  const _InsightsCard({
    required this.sorted,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    String? topCategory;
    double? topCategoryAmount;
    if (sorted.isNotEmpty) {
      topCategory = sorted.first.key;
      topCategoryAmount = sorted.first.value;
    }

    String? insight;
    if (topCategory != null && topCategoryAmount! > 0) {
      insight =
          'Tu categoría con más gasto es $topCategory (${formatCurrencyFull(topCategoryAmount)})';
    }

    if (insight == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(borderColor: kAccent.withOpacity(0.4)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const PhosphorIcon(
              PhosphorIconsLight.chartLineUp,
              color: kAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dato clave',
                  style: TextStyle(
                    color: kAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight,
                  style: const TextStyle(
                    color: kTextMain,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment method breakdown ──────────────────────────────────────────────────
class _PaymentMethodBreakdown extends StatelessWidget {
  final AppState state;
  const _PaymentMethodBreakdown({required this.state});

  @override
  Widget build(BuildContext context) {
    final methodTotals = <String, double>{};
    for (final e in state.microExpenses) {
      final key = e.paymentMethod.isEmpty ? 'Sin método' : e.paymentMethod;
      methodTotals[key] = (methodTotals[key] ?? 0) + e.amount;
    }
    final sorted = methodTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              PhosphorIcon(PhosphorIconsLight.wallet, color: kAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'Gasto por método de pago',
                style: TextStyle(
                  color: kTextMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...sorted.map((e) {
            final pct = state.totalMicroExpenses > 0
                ? e.value / state.totalMicroExpenses
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(color: kTextMain, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        formatCurrencyFull(e.value),
                        style: const TextStyle(
                          color: kAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: kLine,
                      color: kAccent,
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
