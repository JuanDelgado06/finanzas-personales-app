import 'package:flutter/services.dart';

/// Convierte el texto de un campo de monto ("1,000.50") a número.
double parseAmount(String text) =>
    double.tryParse(text.replaceAll(',', '')) ?? 0;

/// Formatea un monto para mostrarlo dentro de un campo: "1,000" (sin
/// decimales si es entero, vacío si es 0).
String formatAmountInput(double value) {
  if (value == 0) return '';
  final raw = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
  return _group(raw);
}

String _group(String raw) {
  final parts = raw.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
}

/// Solo dígitos y un punto decimal; agrega separador de miles al escribir
/// (1000 → 1,000) y mantiene el cursor en su sitio.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Limpia: solo dígitos y el primer punto.
    final buffer = StringBuffer();
    var seenDot = false;
    var digitsBeforeCursor = 0;
    for (var i = 0; i < newValue.text.length; i++) {
      final ch = newValue.text[i];
      final isDigit = ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
      if (isDigit || (ch == '.' && !seenDot)) {
        if (ch == '.') seenDot = true;
        buffer.write(ch);
        if (i < newValue.selection.end) digitsBeforeCursor++;
      }
    }
    final formatted = _group(buffer.toString());

    // Reubica el cursor: tras el mismo número de caracteres significativos.
    var seen = 0;
    var offset = formatted.length;
    if (digitsBeforeCursor == 0) {
      offset = 0;
    } else {
      for (var i = 0; i < formatted.length; i++) {
        if (formatted[i] != ',') seen++;
        if (seen == digitsBeforeCursor) {
          offset = i + 1;
          break;
        }
      }
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
