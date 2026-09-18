import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'add_expense_sheet.dart';

void showAddExpenseSheet(
  BuildContext context,
  AppState state, {
  int? editIndex,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => AddExpenseSheet(state: state, editIndex: editIndex),
  );
}
