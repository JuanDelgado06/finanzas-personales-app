import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_personales/models/budget_item.dart';
import 'package:finanzas_personales/models/monthly_budget.dart';
import 'package:finanzas_personales/services/budget_pdf_service.dart';

void main() {
  test('genera bytes de PDF válidos para un presupuesto con datos completos', () async {
    final budget = MonthlyBudget(
      monthName: 'Marzo 2026',
      assets: [BudgetItem(id: '1', name: 'Nequi', amount: 300000)],
      owed: const [],
      liabilities: [Liability(id: '2', name: 'Arriendo', amount: 100000)],
      creditCards: [
        CreditCard(
          id: '3',
          name: 'Visa',
          creditLimit: 500000,
          balance: 480000,
          minimum: 25000,
          paymentTotal: 20000,
        ),
      ],
      microExpenses: [
        MicroExpense(
          id: 'm1',
          amount: 15000,
          category: 'Comida',
          paymentMethod: 'Nequi',
          createdAt: DateTime(2026, 3, 5),
        ),
        MicroExpense(
          id: 'm2',
          amount: 8000,
          category: 'Transporte',
          paymentMethod: 'Visa',
          createdAt: DateTime(2026, 3, 6),
        ),
      ],
      microExpenseCategories: const ['Comida', 'Transporte'],
      totalAssets: 300000,
      totalLiabilities: 143000,
      netWorth: 157000,
      partialNetWorth: 148000,
      createdAt: DateTime.now().toIso8601String(),
    );

    final bytes = await buildBudgetPdf(budget: budget);

    expect(bytes, isNotEmpty);
    // Los PDF siempre empiezan con la firma "%PDF-".
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('no falla con un presupuesto vacío (sin gastos hormiga)', () async {
    final budget = MonthlyBudget(
      monthName: 'Abril 2026',
      assets: const [],
      owed: const [],
      liabilities: const [],
      creditCards: const [],
      microExpenses: const [],
      microExpenseCategories: const [],
      totalAssets: 0,
      totalLiabilities: 0,
      netWorth: 0,
      partialNetWorth: 0,
      createdAt: DateTime.now().toIso8601String(),
    );

    final bytes = await buildBudgetPdf(budget: budget);

    expect(bytes, isNotEmpty);
  });
}
