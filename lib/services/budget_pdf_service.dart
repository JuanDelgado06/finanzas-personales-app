import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/budget_item.dart';
import '../models/monthly_budget.dart';

/// Carga la tipografía Inter (la misma que usa la app) con soporte Unicode,
/// necesaria para que tildes y "ñ" se vean bien en el PDF. Si no hay red
/// (Google Fonts se descarga la primera vez), se sigue generando el PDF con
/// la fuente base del paquete `pdf`, que no tiene esos caracteres.
Future<pw.ThemeData?> _loadPdfTheme() async {
  try {
    final regular = await PdfGoogleFonts.interRegular();
    final bold = await PdfGoogleFonts.interBold();
    return pw.ThemeData.withFont(base: regular, bold: bold);
  } catch (e) {
    debugPrint('No se pudo cargar la fuente del PDF, se usa la de respaldo: $e');
    return null;
  }
}

/// Construye un PDF legible (resumen + gráfico) a partir de un
/// [MonthlyBudget] guardado. Es una función pura: no depende de [AppState]
/// ni de que el presupuesto esté cargado en pantalla, así que sirve tanto
/// para el presupuesto activo como para cualquiera del historial.
///
/// [pieChartImage] es opcional: si se pasa (capturada desde la pantalla de
/// gráficos con un `RepaintBoundary`), se incrusta tal cual; si no, el PDF
/// solo muestra la tabla de categorías sin la imagen del gráfico.
Future<Uint8List> buildBudgetPdf({
  required MonthlyBudget budget,
  Uint8List? pieChartImage,
}) async {
  final theme = await _loadPdfTheme();
  final doc = pw.Document(theme: theme);

  final liabilitiesOnly = budget.liabilities
      .whereType<Liability>()
      .fold(0.0, (sum, l) => sum + l.amount);
  final creditCardsPaymentTotal =
      budget.creditCards.fold(0.0, (sum, c) => sum + c.paymentTotal);
  final creditCardsMinimum =
      budget.creditCards.fold(0.0, (sum, c) => sum + c.minimum);
  final totalMicroExpenses =
      budget.microExpenses.fold(0.0, (sum, m) => sum + m.amount);
  final fixedExpenses = liabilitiesOnly + creditCardsPaymentTotal;
  final minimumPayments = liabilitiesOnly + creditCardsMinimum;

  final usagePercent = budget.totalAssets > 0
      ? (budget.totalLiabilities / budget.totalAssets * 100).clamp(0, 999)
      : 0.0;

  final categoryTotals = <String, double>{};
  for (final e in budget.microExpenses) {
    categoryTotals[e.category] = (categoryTotals[e.category] ?? 0) + e.amount;
  }
  final sortedCategories = categoryTotals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final methodTotals = <String, double>{};
  for (final e in budget.microExpenses) {
    final key = e.paymentMethod.isEmpty ? 'Sin método' : e.paymentMethod;
    methodTotals[key] = (methodTotals[key] ?? 0) + e.amount;
  }
  final sortedMethods = methodTotals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final mostActiveDay = _mostActiveDay(budget.microExpenses);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            budget.monthName,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Generado el ${_formatDate(DateTime.now())} · Finanzas Personales',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 14),
        ],
      ),
      build: (context) => [
        _sectionTitle('Resumen financiero'),
        _summaryTable([
          _Row('Total activos', budget.totalAssets, _accent),
          _Row('Gastos fijos', fixedExpenses, _danger),
          _Row('Gastos hormiga', totalMicroExpenses, _warning),
          _Row('Pago mínimo total', minimumPayments, _amber),
          _Row(
            'Balance neto',
            budget.netWorth,
            budget.netWorth >= 0 ? _success : _danger,
            bold: true,
          ),
          _Row(
            'Balance parcial',
            budget.partialNetWorth,
            budget.partialNetWorth >= 0 ? _success : _danger,
          ),
          if (budget.totalSavings > 0) ...[
            _Row('Ahorro apartado', budget.totalSavings, _saving),
            _Row(
              'Disponible para gastar',
              budget.netWorth - budget.totalSavings,
              budget.netWorth - budget.totalSavings >= 0 ? _success : _danger,
              bold: true,
            ),
          ],
        ]),
        pw.SizedBox(height: 18),
        _sectionTitle('Indicadores clave'),
        pw.Bullet(text: 'Uso del presupuesto: ${usagePercent.toStringAsFixed(0)}%'),
        if (mostActiveDay != null)
          pw.Bullet(
            text:
                'Día con más gastos registrados: ${mostActiveDay.key} · '
                '${mostActiveDay.value} ${mostActiveDay.value == 1 ? 'gasto' : 'gastos'}',
          ),
        if (sortedCategories.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          _sectionTitle('Gastos hormiga por categoría'),
          if (pieChartImage != null) ...[
            pw.Center(
              child: pw.Image(pw.MemoryImage(pieChartImage), width: 220, height: 220),
            ),
            pw.SizedBox(height: 12),
          ],
          _categoryTable(sortedCategories, totalMicroExpenses),
        ],
        if (sortedMethods.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          _sectionTitle('Gasto por método de pago'),
          _categoryTable(sortedMethods, totalMicroExpenses),
        ],
      ],
    ),
  );

  return doc.save();
}

class _Row {
  final String label;
  final double value;
  final PdfColor color;
  final bool bold;
  const _Row(this.label, this.value, this.color, {this.bold = false});
}

const _accent = PdfColor.fromInt(0xFF00D37F);
const _danger = PdfColor.fromInt(0xFFFF4D6A);
const _success = PdfColor.fromInt(0xFF00D37F);
const _warning = PdfColor.fromInt(0xFFA78BFA);
const _amber = PdfColor.fromInt(0xFFF59E0B);
const _saving = PdfColor.fromInt(0xFF38BDF8);

const List<PdfColor> _pieColors = [
  _accent,
  _warning,
  _danger,
  _success,
  _amber,
  PdfColor.fromInt(0xFF14B8A6),
  PdfColor.fromInt(0xFFEC4899),
  PdfColor.fromInt(0xFF8B5CF6),
  PdfColor.fromInt(0xFFEF4444),
  PdfColor.fromInt(0xFF10B981),
];

pw.Widget _sectionTitle(String text) => pw.Text(
      text,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
    );

pw.Widget _summaryTable(List<_Row> rows) {
  return pw.Table(
    columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1)},
    children: rows
        .map(
          (r) => pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  r.label,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: r.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  _formatCurrency(r.value),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: r.color,
                    fontWeight: r.bold ? pw.FontWeight.bold : pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        )
        .toList(),
  );
}

pw.Widget _categoryTable(List<MapEntry<String, double>> entries, double total) {
  return pw.Table(
    columnWidths: const {
      0: pw.FixedColumnWidth(14),
      1: pw.FlexColumnWidth(2),
      2: pw.FlexColumnWidth(1),
      3: pw.FlexColumnWidth(1),
    },
    children: entries.asMap().entries.map((e) {
      final color = _pieColors[e.key % _pieColors.length];
      final pct = total > 0 ? (e.value.value / total * 100) : 0;
      return pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Container(
              width: 8,
              height: 8,
              decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(e.value.key, style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(
              _formatCurrency(e.value.value),
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(
              '${pct.toStringAsFixed(0)}%',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
        ],
      );
    }).toList(),
  );
}

MapEntry<String, int>? _mostActiveDay(List<MicroExpense> expenses) {
  if (expenses.isEmpty) return null;
  const weekdays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  final countsByDay = <DateTime, int>{};
  for (final expense in expenses) {
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
  final label = '${weekdays[topDay.key.weekday - 1]} ${topDay.key.day}';
  return MapEntry(label, topDay.value);
}

String _formatCurrency(double value) {
  final abs = value.abs();
  final formatted = abs.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
  return value < 0 ? '-\$$formatted' : '\$$formatted';
}

String _formatDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}
