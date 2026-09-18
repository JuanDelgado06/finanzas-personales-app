import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'category_icon.dart';

class AddExpenseSheet extends StatefulWidget {
  final AppState state;
  final int? editIndex;
  const AddExpenseSheet({required this.state, this.editIndex});

  @override
  State<AddExpenseSheet> createState() => AddExpenseSheetState();
}

class AddExpenseSheetState extends State<AddExpenseSheet> {
  late final TextEditingController _amountCtrl;
  late String _selectedCategory;
  late String _selectedPayment;

  @override
  void initState() {
    super.initState();
    final cats = widget.state.microExpenseCategories;
    final pays = widget.state.paymentMethodNames.isNotEmpty
        ? widget.state.paymentMethodNames
        : ['Efectivo'];
    if (widget.editIndex != null) {
      final item = widget.state.microExpenses[widget.editIndex!];
      _amountCtrl = TextEditingController(
        text: item.amount == 0 ? '' : item.amount.toStringAsFixed(0),
      );
      _selectedCategory = cats.contains(item.category)
          ? item.category
          : cats.first;
      _selectedPayment = pays.contains(item.paymentMethod)
          ? item.paymentMethod
          : pays.first;
    } else {
      _amountCtrl = TextEditingController();
      _selectedCategory = cats.isNotEmpty ? cats.first : 'Otros';
      _selectedPayment = pays.first;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un monto válido'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (widget.editIndex != null) {
      widget.state.updateMicroExpenseDirect(
        widget.editIndex!,
        amount: amount,
        category: _selectedCategory,
        paymentMethod: _selectedPayment,
      );
    } else {
      widget.state.addMicroExpenseDirect(
        amount: amount,
        category: _selectedCategory,
        paymentMethod: _selectedPayment,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editIndex != null;
    final cats = widget.state.microExpenseCategories;
    final pays = widget.state.paymentMethodNames.isNotEmpty
        ? widget.state.paymentMethodNames
        : ['Efectivo'];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kLine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isEdit ? 'Editar gasto' : 'Nuevo gasto',
                style: const TextStyle(
                  color: kTextMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),

              // ── Amount hero ──────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    const Text(
                      'MONTO',
                      style: TextStyle(
                        color: kTextSoft,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            '\$',
                            style: TextStyle(
                              color: kTextSoft,
                              fontSize: 22,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IntrinsicWidth(
                          child: TextField(
                            controller: _amountCtrl,
                            autofocus: !isEdit,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            style: const TextStyle(
                              color: kTextMain,
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -2,
                            ),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: Color(0xFF2E3E50),
                                fontSize: 44,
                                fontWeight: FontWeight.w700,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 2,
                      width: 120,
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Category ─────────────────────────────────────────────────
              const Text(
                'CATEGORÍA',
                style: TextStyle(
                  color: kTextSoft,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cats.map((cat) {
                  final selected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? kAccent : kSurfaceHover,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? kAccent : kLine),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            categoryIcon(cat),
                            size: 14,
                            color: selected ? Colors.white : kTextSoft,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat,
                            style: TextStyle(
                              color: selected ? Colors.white : kTextMain,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ── Payment method ────────────────────────────────────────────
              const Text(
                'PAGADO CON',
                style: TextStyle(
                  color: kTextSoft,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: pays.map((pay) {
                    final selected = pay == _selectedPayment;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedPayment = pay),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? kSurface : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? kAccent : kLine,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIconsLight.wallet,
                                size: 13,
                                color: selected ? kAccent : kTextSoft,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                pay,
                                style: TextStyle(
                                  color: selected ? kAccent : kTextMain,
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 28),

              // ── Confirm ───────────────────────────────────────────────────
              ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isEdit ? 'Guardar cambios' : 'Agregar gasto',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
