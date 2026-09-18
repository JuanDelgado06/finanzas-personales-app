import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'micro_expenses/actions.dart';
import 'micro_expenses/balance_card.dart';
import 'micro_expenses/categories.dart';
import 'micro_expenses/day_filter_bar.dart';
import 'micro_expenses/empty_states.dart';
import 'micro_expenses/expense_list.dart';
import 'micro_expenses/status_bar.dart';

class MicroExpensesScreen extends StatefulWidget {
  const MicroExpensesScreen({super.key});

  @override
  State<MicroExpensesScreen> createState() => _MicroExpensesScreenState();
}

class _MicroExpensesScreenState extends State<MicroExpensesScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _showAllExpenses = false;

  List<int> _expenseIndexesForSelectedDate(AppState state) {
    if (_showAllExpenses) {
      return List<int>.generate(state.microExpenses.length, (index) => index);
    }
    return [
      for (var i = 0; i < state.microExpenses.length; i++)
        if (_isSameDay(state.microExpenses[i].createdAt, _selectedDate)) i,
    ];
  }

  bool _isSameDay(DateTime first, DateTime second) {
    final firstLocal = first.toLocal();
    final secondLocal = second.toLocal();
    return firstLocal.year == secondLocal.year &&
        firstLocal.month == secondLocal.month &&
        firstLocal.day == secondLocal.day;
  }

  String _selectedDateLabel() {
    final today = DateTime.now();
    if (_isSameDay(_selectedDate, today)) return 'Hoy';
    if (_isSameDay(_selectedDate, today.subtract(const Duration(days: 1)))) {
      return 'Ayer';
    }
    const weekdays = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${weekdays[_selectedDate.weekday - 1]} ${_selectedDate.day} de '
        '${months[_selectedDate.month - 1]}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'CO'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _showAllExpenses = false;
      });
    }
  }

  void _changeDay(int days) {
    final nextDate = _selectedDate.add(Duration(days: days));
    final today = DateTime.now();
    if (nextDate.isAfter(DateTime(today.year, today.month, today.day))) return;
    setState(() {
      _selectedDate = nextDate;
      _showAllExpenses = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final expenseIndexes = _expenseIndexesForSelectedDate(state);

    return Scaffold(
      backgroundColor: kAppBg,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          showAddExpenseSheet(context, state);
        },
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        child: const PhosphorIcon(PhosphorIconsLight.plus, size: 22),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: MiniBalanceCard(state: state)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: CategoriesRow(state: state),
            ),
          ),
          SliverToBoxAdapter(
            child: DayFilterBar(
              label: _showAllExpenses
                  ? 'Todos los gastos'
                  : _selectedDateLabel(),
              onPrevious: () => _changeDay(-1),
              onNext: () => _changeDay(1),
              onPickDate: _pickDate,
              onShowAll: () => setState(() => _showAllExpenses = true),
              showAll: _showAllExpenses,
              canGoPrevious: !_showAllExpenses,
              canGoNext:
                  !_showAllExpenses &&
                  !_isSameDay(_selectedDate, DateTime.now()),
            ),
          ),
          if (state.microExpenses.isEmpty)
            SliverToBoxAdapter(child: EmptyMicroState(state: state))
          else if (expenseIndexes.isEmpty)
            SliverToBoxAdapter(
              child: EmptyDayState(
                dateLabel: _selectedDateLabel(),
                onAddExpense: () => showAddExpenseSheet(context, state),
              ),
            )
          else
            GroupedExpenseList(state: state, expenseIndexes: expenseIndexes),
          SliverToBoxAdapter(child: SaveStatusBar(state: state)),
          const SliverToBoxAdapter(child: SizedBox(height: 104)),
        ],
      ),
    );
  }
}
