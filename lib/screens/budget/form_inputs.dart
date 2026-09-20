import 'package:flutter/material.dart';
import '../../utils/amount_format.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../theme/app_theme.dart';

class AmountInput extends StatefulWidget {
  final double initial;
  final ValueChanged<double> onChanged;
  final bool compact;
  const AmountInput({
    required this.initial,
    required this.onChanged,
    this.compact = false,
  });
  @override
  State<AmountInput> createState() => AmountInputState();
}

class AmountInputState extends State<AmountInput> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: formatAmountInput(widget.initial),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AmountInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Compara por valor (no por texto) para no pisar lo que el usuario está
    // escribiendo, p. ej. "12." o el formato con comas.
    if (parseAmount(_ctrl.text) == widget.initial) return;
    final nextText = formatAmountInput(widget.initial);
    _ctrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [ThousandsFormatter()],
      style: TextStyle(color: kTextMain, fontSize: widget.compact ? 13 : 14),
      textAlign: TextAlign.right,
      onChanged: (v) => widget.onChanged(parseAmount(v)),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: const TextStyle(color: kTextSoft),
        prefixText: '\$ ',
        prefixStyle: const TextStyle(color: kTextSoft, fontSize: 13),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: widget.compact ? 10 : 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kAccent),
        ),
      ),
    );
  }
}

class NameInput extends StatefulWidget {
  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;
  const NameInput({
    required this.initial,
    required this.hint,
    required this.onChanged,
  });
  @override
  State<NameInput> createState() => NameInputState();
}

class NameInputState extends State<NameInput> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NameInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.initial;
    if (_ctrl.text == nextText) return;
    _ctrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      style: const TextStyle(color: kTextMain, fontSize: 13),
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: kTextSoft, fontSize: 13),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kAccent),
        ),
      ),
    );
  }
}

class DayInput extends StatefulWidget {
  final int? initial;
  final String hint;
  final ValueChanged<int?> onChanged;
  const DayInput({
    required this.initial,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<DayInput> createState() => DayInputState();
}

class DayInputState extends State<DayInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial?.toString() ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DayInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.initial?.toString() ?? '';
    if (_ctrl.text == nextText) return;
    _ctrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: const TextStyle(color: kTextMain, fontSize: 13),
      onChanged: (v) {
        final parsed = int.tryParse(v);
        if (parsed == null || parsed < 1 || parsed > 31) {
          widget.onChanged(null);
          return;
        }
        widget.onChanged(parsed);
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: kTextSoft, fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kAccent),
        ),
      ),
    );
  }
}

class RemoveBtn extends StatelessWidget {
  final VoidCallback onTap;
  const RemoveBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: kDanger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kDanger.withOpacity(0.25)),
        ),
        child: const PhosphorIcon(
          PhosphorIconsLight.trash,
          color: kDanger,
          size: 16,
        ),
      ),
    );
  }
}
