import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../state/app_state.dart';
import '../models/budget_item.dart';
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
    final sorted = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Build liabilities bar data
    final fixedItems = state.liabilities.map((l) {
      if (l is CreditCard) return MapEntry(l.name, l.minimum);
      if (l is Liability) return MapEntry((l as Liability).name, l.amount);
      return const MapEntry('', 0.0);
    }).where((e) => e.value > 0).toList();

    return Scaffold(
      backgroundColor: kAppBg,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Balance card
          _BalanceCard(state: state),
          const SizedBox(height: 16),
          if (sorted.isNotEmpty) ...[
            _ChartSection(
              title: 'Gastos Hormiga por Categoría',
              icon: Icons.pie_chart_outline,
              iconColor: kWarning,
              child: _MicroPieChart(data: sorted, total: state.totalMicroExpenses),
            ),
            const SizedBox(height: 16),
          ],
          if (fixedItems.isNotEmpty) ...[
            _ChartSection(
              title: 'Gastos Fijos',
              icon: Icons.bar_chart,
              iconColor: kDanger,
              child: _LiabilitiesBarChart(items: fixedItems),
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
      _BalRow('Pago mínimo total', state.partialLiabilitiesWithoutMicro, const Color(0xFFF59E0B)),
      _BalRow('Balance neto', state.netWorth, state.netWorth >= 0 ? kSuccess : kDanger, bold: true),
      _BalRow('Balance parcial', state.partialNetWorth, state.partialNetWorth >= 0 ? kSuccess : kDanger),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_outlined, color: kAccent, size: 18),
              SizedBox(width: 8),
              Text('Resumen financiero', style: TextStyle(color: kTextMain, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(r.label, style: TextStyle(color: kTextSoft, fontSize: 13, fontWeight: r.bold ? FontWeight.w600 : FontWeight.normal)),
                    const Spacer(),
                    Text(formatCurrencyFull(r.value),
                        style: TextStyle(color: r.color, fontSize: 13, fontWeight: r.bold ? FontWeight.w700 : FontWeight.w500)),
                  ],
                ),
              )),
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

// ── Chart section wrapper ─────────────────────────────────────────────────────
class _ChartSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _ChartSection({required this.title, required this.icon, required this.iconColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: kTextMain, fontWeight: FontWeight.w600, fontSize: 15)),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Pie chart ─────────────────────────────────────────────────────────────────
final List<Color> _pieColors = [
  kAccent, kWarning, kDanger, kSuccess,
  const Color(0xFFF59E0B), const Color(0xFF14B8A6), const Color(0xFFEC4899),
  const Color(0xFF8B5CF6), const Color(0xFFEF4444), const Color(0xFF10B981),
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
        titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        showTitle: pct >= 5,
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(PieChartData(
            sections: sections,
            sectionsSpace: 2,
            centerSpaceRadius: 40,
          )),
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
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Text('${e.value.key} ${formatCurrency(e.value.value)}', style: const TextStyle(color: kTextSoft, fontSize: 11)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Bar chart ─────────────────────────────────────────────────────────────────
class _LiabilitiesBarChart extends StatelessWidget {
  final List<MapEntry<String, double>> items;
  const _LiabilitiesBarChart({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxVal = items.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final groups = items.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.value,
            color: kDanger,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return SizedBox(
      height: 200,
      child: BarChart(BarChartData(
        maxY: maxVal * 1.2,
        barGroups: groups,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (v, m) => Text(formatCurrency(v), style: const TextStyle(color: kTextSoft, fontSize: 9)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, m) {
                final idx = v.toInt();
                if (idx < 0 || idx >= items.length) return const SizedBox.shrink();
                final name = items[idx].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(name.length > 8 ? '${name.substring(0, 7)}…' : name,
                      style: const TextStyle(color: kTextSoft, fontSize: 9)),
                );
              },
            ),
          ),
        ),
      )),
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
    final sorted = methodTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: kAccent, size: 18),
              SizedBox(width: 8),
              Text('Gasto por método de pago', style: TextStyle(color: kTextMain, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          ...sorted.map((e) {
            final pct = state.totalMicroExpenses > 0 ? e.value / state.totalMicroExpenses : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(e.key, style: const TextStyle(color: kTextMain, fontSize: 13)),
                      const Spacer(),
                      Text(formatCurrencyFull(e.value), style: const TextStyle(color: kAccent, fontSize: 13, fontWeight: FontWeight.w600)),
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
