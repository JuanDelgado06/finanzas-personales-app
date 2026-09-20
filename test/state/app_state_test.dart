import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_personales/models/budget_item.dart';
import 'package:finanzas_personales/models/monthly_budget.dart';
import 'package:finanzas_personales/services/auth_service.dart';
import 'package:finanzas_personales/state/app_state.dart';

/// Doble de prueba: no toca Firebase real, así los tests de lógica de
/// negocio (totales, tarjetas, elección de mes) corren sin red ni platform
/// channels.
class FakeAuthService implements AuthService {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();
  @override
  User? get currentUser => null;
  @override
  bool get isAnonymous => true;
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => null;
  @override
  Future<UserCredential> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<UserCredential> signInAnonymously() => throw UnimplementedError();
  @override
  Future<UserCredential> linkAnonymousWithGoogle() =>
      throw UnimplementedError();
  @override
  Future<void> signOut() async {}
}

MonthlyBudget _budgetFor(String monthName) => MonthlyBudget(
  monthName: monthName,
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Totales de presupuesto', () {
    test('netWorth y partialNetWorth reflejan activos, pasivos y tarjetas', () {
      final state = AppState(authService: FakeAuthService());
      state.assets = [BudgetItem(id: '1', name: 'Nequi', amount: 100000)];
      state.owed = [];
      state.liabilities = [Liability(id: '2', name: 'Arriendo', amount: 30000)];
      state.creditCards = [
        CreditCard(
          id: '3',
          name: 'Visa',
          creditLimit: 500000,
          balance: 0,
          minimum: 5000,
          paymentTotal: 20000,
        ),
      ];
      state.microExpenses = [];

      expect(state.totalAssets, 100000);
      expect(state.totalLiabilitiesWithoutMicro, 30000 + 20000);
      expect(state.netWorth, 100000 - (30000 + 20000));
      expect(state.partialNetWorth, 100000 - (30000 + 5000));
    });
  });

  group('Gastos hormiga y tarjetas de crédito', () {
    test(
      'addMicroExpenseDirect con tarjeta sube paymentTotal y baja el cupo disponible',
      () {
        final state = AppState(authService: FakeAuthService());
        state.creditCards = [
          CreditCard(
            id: 'c1',
            name: 'Visa',
            creditLimit: 500000,
            balance: 500000,
            minimum: 0,
            paymentTotal: 0,
          ),
        ];

        state.addMicroExpenseDirect(
          amount: 20000,
          category: 'Comida',
          paymentMethod: 'Visa',
        );

        final card = state.creditCards.first;
        expect(card.paymentTotal, 20000);
        expect(card.balance, 480000);
      },
    );

    test('removeMicroExpense revierte el cargo a la tarjeta', () {
      final state = AppState(authService: FakeAuthService());
      state.creditCards = [
        CreditCard(
          id: 'c1',
          name: 'Visa',
          creditLimit: 500000,
          balance: 500000,
          minimum: 0,
          paymentTotal: 0,
        ),
      ];
      state.addMicroExpenseDirect(
        amount: 20000,
        category: 'Comida',
        paymentMethod: 'Visa',
      );

      state.removeMicroExpense(0);

      final card = state.creditCards.first;
      expect(card.paymentTotal, 0);
      expect(card.balance, 500000);
    });

    test('applyCreditCardPayment descuenta del activo y de la deuda', () {
      final state = AppState(authService: FakeAuthService());
      state.assets = [BudgetItem(id: 'a1', name: 'Nequi', amount: 100000)];
      state.creditCards = [
        CreditCard(
          id: 'c1',
          name: 'Visa',
          creditLimit: 500000,
          balance: 480000,
          minimum: 5000,
          paymentTotal: 20000,
        ),
      ];

      final error = state.applyCreditCardPayment(
        cardId: 'c1',
        assetName: 'Nequi',
        amount: 20000,
      );

      expect(error, isNull);
      expect(state.assets.first.amount, 80000);
      expect(state.creditCards.first.paymentTotal, 0);
      expect(state.creditCards.first.balance, 500000);
    });

    test('applyCreditCardPayment rechaza montos mayores al saldo pendiente', () {
      final state = AppState(authService: FakeAuthService());
      state.assets = [BudgetItem(id: 'a1', name: 'Nequi', amount: 100000)];
      state.creditCards = [
        CreditCard(
          id: 'c1',
          name: 'Visa',
          creditLimit: 500000,
          balance: 480000,
          minimum: 5000,
          paymentTotal: 20000,
        ),
      ];

      final error = state.applyCreditCardPayment(
        cardId: 'c1',
        assetName: 'Nequi',
        amount: 50000,
      );

      expect(error, isNotNull);
      expect(state.creditCards.first.paymentTotal, 20000);
    });
  });

  group('Gasto que supera el efectivo disponible', () {
    MicroExpense gasto(double amount, String method) => MicroExpense(
      id: 'g${amount.toInt()}$method',
      amount: amount,
      category: 'Otros',
      paymentMethod: method,
      createdAt: DateTime(2026, 9, 1),
    );

    test('50,000 en efectivo y gasto de 51,000 queda en -1,000', () {
      final state = AppState(authService: FakeAuthService());
      state.assets = [BudgetItem(id: 'e', name: 'Efectivo', amount: 50000)];
      state.microExpenses = [gasto(51000, 'Efectivo')];

      expect(state.availableAmountByItemId['e'], -1000);
    });

    test('el exceso no se cuenta dos veces (activos negativos, sin pasivo extra)', () {
      final state = AppState(authService: FakeAuthService());
      state.assets = [BudgetItem(id: 'e', name: 'Efectivo', amount: 50000)];
      state.microExpenses = [gasto(51000, 'Efectivo')];

      expect(state.totalAssets, -1000);
      expect(state.totalLiabilities, 0);
      expect(state.netWorth, -1000);
    });

    test('sin exceso el saldo no cambia de comportamiento', () {
      final state = AppState(authService: FakeAuthService());
      state.assets = [BudgetItem(id: 'e', name: 'Efectivo', amount: 50000)];
      state.microExpenses = [gasto(20000, 'Efectivo')];

      expect(state.availableAmountByItemId['e'], 30000);
      expect(state.netWorth, 30000);
    });

    test('gasto con método sin activo sigue contando como pasivo', () {
      final state = AppState(authService: FakeAuthService());
      state.assets = [BudgetItem(id: 'e', name: 'Efectivo', amount: 50000)];
      state.microExpenses = [gasto(5000, 'Otro medio')];

      expect(state.totalLiabilities, 5000);
      expect(state.netWorth, 45000);
    });

    test('varios activos con el mismo nombre: el exceso va al último', () {
      final state = AppState(authService: FakeAuthService());
      state.assets = [
        BudgetItem(id: 'a', name: 'Efectivo', amount: 10000),
        BudgetItem(id: 'b', name: 'Efectivo', amount: 5000),
      ];
      state.microExpenses = [gasto(16000, 'Efectivo')];

      expect(state.availableAmountByItemId['a'], 0);
      expect(state.availableAmountByItemId['b'], -1000);
    });
  });

  group('Nuevo mes no debe sobrescribir meses ya guardados', () {
    test('resetForm elige el primer mes que todavía no tiene presupuesto', () {
      final state = AppState(authService: FakeAuthService());
      final now = DateTime.now();
      final currentMonthName = state.formatMonthName(now);
      final nextMonthName = state.formatMonthName(
        DateTime(now.year, now.month + 1),
      );

      state.savedBudgets = [_budgetFor(currentMonthName)];

      state.resetForm();

      expect(state.monthName, isNot(currentMonthName));
      expect(state.monthName, nextMonthName);
    });

    test('si el mes actual está libre, resetForm se queda en el mes actual', () {
      final state = AppState(authService: FakeAuthService());
      state.savedBudgets = [];

      state.resetForm();

      expect(state.monthName, state.formatMonthName(DateTime.now()));
    });

    test('salta varios meses consecutivos ya guardados', () {
      final state = AppState(authService: FakeAuthService());
      final now = DateTime.now();
      state.savedBudgets = [
        _budgetFor(state.formatMonthName(DateTime(now.year, now.month))),
        _budgetFor(state.formatMonthName(DateTime(now.year, now.month + 1))),
      ];

      state.resetForm();

      expect(
        state.monthName,
        state.formatMonthName(DateTime(now.year, now.month + 2)),
      );
    });
  });

  group('Eliminar presupuestos del historial', () {
    test(
      'un presupuesto que nunca se sincronizó (sin monthSlug) se borra local '
      'sin llamar a la red',
      () async {
        final state = AppState(authService: FakeAuthService());
        final localOnly = _budgetFor('Marzo 2026');
        state.savedBudgets = [localOnly];

        final ok = await state.deleteBudget(localOnly);

        expect(ok, isTrue);
        expect(state.savedBudgets, isEmpty);
      },
    );
  });

  group('Importar presupuesto desde texto compartido', () {
    test('conserva las tarjetas de crédito al hacer roundtrip exportar/importar', () async {
      final state = AppState(authService: FakeAuthService());
      final original = MonthlyBudget(
        monthName: 'Marzo 2026',
        assets: [BudgetItem(id: '1', name: 'Nequi', amount: 100000)],
        owed: const [],
        liabilities: const [],
        creditCards: [
          CreditCard(
            id: 'c1',
            name: 'Visa',
            creditLimit: 500000,
            balance: 480000,
            minimum: 25000,
            paymentTotal: 20000,
          ),
        ],
        microExpenses: const [],
        microExpenseCategories: const [],
        totalAssets: 100000,
        totalLiabilities: 20000,
        netWorth: 80000,
        partialNetWorth: 75000,
        createdAt: DateTime.now().toIso8601String(),
      );

      final text = state.exportBudgetToText(original);
      final imported = await state.importBudgetFromText(text);

      expect(imported, isNotNull);
      expect(imported!.creditCards, hasLength(1));
      final card = imported.creditCards.first;
      expect(card.name, 'Visa');
      expect(card.creditLimit, 500000);
      expect(card.balance, 480000);
      expect(card.minimum, 25000);
      expect(card.paymentTotal, 20000);
    });
  });
}
