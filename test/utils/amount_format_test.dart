import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_personales/utils/amount_format.dart';

TextEditingValue _type(String text, [int? cursor]) {
  return ThousandsFormatter().formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor ?? text.length),
    ),
  );
}

void main() {
  test('agrega separador de miles', () {
    expect(_type('1000').text, '1,000');
    expect(_type('10000').text, '10,000');
    expect(_type('1234567').text, '1,234,567');
    expect(_type('999').text, '999');
  });

  test('conserva decimales y descarta caracteres inválidos', () {
    expect(_type('1000.50').text, '1,000.50');
    expect(_type('12.').text, '12.');
    expect(_type('1a2.3.4').text, '12.34');
  });

  test('cursor queda al final al escribir y se reubica al insertar', () {
    expect(_type('1000').selection.baseOffset, 5);
    // "1,000" con un dígito insertado antes de la coma: "12,000" → cursor tras el 2
    expect(_type('12,000', 2).text, '12,000');
    expect(_type('12,000', 2).selection.baseOffset, 2);
  });

  test('parseAmount y formatAmountInput', () {
    expect(parseAmount('1,000.5'), 1000.5);
    expect(parseAmount(''), 0);
    expect(formatAmountInput(0), '');
    expect(formatAmountInput(1000), '1,000');
    expect(formatAmountInput(1234.5), '1,234.5');
  });
}
