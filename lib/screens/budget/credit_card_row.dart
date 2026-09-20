import 'package:flutter/material.dart';
import '../../utils/amount_format.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/budget_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'form_inputs.dart';

class _CardTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const spacing = 22.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }

    // Reflejo luminoso diagonal superior
    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.07),
          Colors.transparent,
          Colors.transparent,
          Colors.white.withOpacity(0.03),
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(16),
      ),
      sheen,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CreditCardRow extends StatefulWidget {
  final int index;
  final CreditCard item;
  final VoidCallback onRemove;

  const CreditCardRow({
    required this.index,
    required this.item,
    required this.onRemove,
  });

  @override
  State<CreditCardRow> createState() => CreditCardRowState();
}

class CreditCardRowState extends State<CreditCardRow> {
  late bool _expanded;
  late final TextEditingController _abonoCtrl;
  String _abonoAssetName = '';

  double _derivedBalance() {
    final value = widget.item.creditLimit - widget.item.paymentTotal;
    return value > 0 ? value : 0;
  }

  void _syncDerivedBalance() {
    widget.item.balance = _derivedBalance();
  }

  @override
  void initState() {
    super.initState();
    _expanded = false;
    _abonoCtrl = TextEditingController();
    _syncDerivedBalance();
  }

  @override
  void dispose() {
    _abonoCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CreditCardRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDerivedBalance();
  }

  void _applyPayment(AppState state) {
    final messenger = ScaffoldMessenger.of(context);
    final amount = parseAmount(_abonoCtrl.text);

    if (_abonoAssetName.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Selecciona un activo para pagar la tarjeta'),
          backgroundColor: kDanger,
        ),
      );
      return;
    }

    final error = state.applyCreditCardPayment(
      cardId: widget.item.id,
      assetName: _abonoAssetName,
      amount: amount,
    );

    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: kDanger),
      );
      return;
    }

    _abonoCtrl.clear();
    HapticFeedback.lightImpact();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Abono aplicado a la tarjeta'),
        backgroundColor: kSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final assetNames = state.assetNames;
    if (assetNames.isEmpty) {
      _abonoAssetName = '';
    } else if (!assetNames.contains(_abonoAssetName)) {
      _abonoAssetName = assetNames.first;
    }

    final cardName = widget.item.name.trim();
    final hasName = cardName.isNotEmpty;
    final currentBalance = _derivedBalance();
    widget.item.balance = currentBalance;
    final utilization = widget.item.creditLimit > 0
        ? (widget.item.paymentTotal / widget.item.creditLimit * 100).clamp(
            0,
            100,
          )
        : 0;
    final numericId = widget.item.id.replaceAll(RegExp(r'[^0-9]'), '');
    final last4 = numericId.length >= 4
        ? numericId.substring(numericId.length - 4)
        : numericId.padLeft(4, '0');
    const plateDark = Color(0xFF050607);
    const plateMid = Color(0xFF121417);
    const metal = Color(0xFFBAC1CB);
    const softMetal = Color(0xFF7D8592);
    const whiteInk = Color(0xFFECEFF3);

    return Column(
      children: [
        // ── Credit Card Visual ──────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0E0E0E),
                  Color(0xFF1C1C1E),
                  Color(0xFF111113),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Textura: líneas diagonales tipo seda
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CustomPaint(
                    painter: _CardTexturePainter(),
                    size: const Size(double.infinity, 190),
                  ),
                ),
                // Contenido
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: nombre + botón eliminar + logo
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            hasName ? cardName : 'Nueva Tarjeta',
                            style: const TextStyle(
                              color: Color(0xFFECEFF3),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: widget.onRemove,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Center(
                                child: PhosphorIcon(
                                  PhosphorIconsLight.trash,
                                  color: Colors.red.shade200,
                                  size: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Logo doble círculo (estilo red de pago)
                          SizedBox(
                            width: 36,
                            height: 22,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFEB001B),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 14,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(
                                        0xFFF79E1B,
                                      ).withOpacity(0.85),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Número de tarjeta
                      Text(
                        '••••  ••••  ••••  $last4',
                        style: const TextStyle(
                          color: Color(0xFFECEFF3),
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2.8,
                        ),
                      ),
                      const Spacer(),
                      // Fecha de validez
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CUPO',
                                style: TextStyle(
                                  color: const Color(0xFF7D8592),
                                  fontSize: 8,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatCurrencyFull(widget.item.creditLimit),
                                style: const TextStyle(
                                  color: Color(0xFFECEFF3),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'SALDO',
                                style: TextStyle(
                                  color: const Color(0xFF7D8592),
                                  fontSize: 8,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatCurrencyFull(widget.item.balance),
                                style: const TextStyle(
                                  color: Color(0xFFECEFF3),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Barra de utilización
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: (utilization / 100).toDouble(),
                                minHeight: 3,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  utilization > 80
                                      ? Colors.red.shade400
                                      : const Color(0xFFBAC1CB),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'USO ${utilization.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Color(0xFF7D8592),
                              fontSize: 9,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Expanded Editor ────────────────────────────────────────────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Container(
            margin: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kSurfaceHover,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kLine),
            ),
            child: Column(
              children: [
                // Nombre
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nombre de tarjeta',
                            style: TextStyle(color: kTextSoft, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          NameInput(
                            initial: widget.item.name,
                            hint: 'Ej: Visa, Mastercard, Amex',
                            onChanged: (v) {
                              widget.item.name = v;
                              state.markBudgetDirty();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Cupo y Saldo
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cupo',
                            style: TextStyle(color: kTextSoft, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          AmountInput(
                            initial: widget.item.creditLimit,
                            compact: true,
                            onChanged: (v) {
                              widget.item.creditLimit = v;
                              _syncDerivedBalance();
                              state.markBudgetDirty();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Saldo',
                            style: TextStyle(color: kTextSoft, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x11FFFFFF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kLine),
                            ),
                            child: Text(
                              formatCurrencyFull(currentBalance),
                              style: const TextStyle(
                                color: kTextMain,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Pagos
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pago mínimo',
                            style: TextStyle(color: kTextSoft, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          AmountInput(
                            initial: widget.item.minimum,
                            compact: true,
                            onChanged: (v) {
                              widget.item.minimum = v;
                              state.markBudgetDirty();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pago total',
                            style: TextStyle(color: kTextSoft, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          AmountInput(
                            initial: widget.item.paymentTotal,
                            compact: true,
                            onChanged: (v) {
                              widget.item.paymentTotal = v;
                              _syncDerivedBalance();
                              state.markBudgetDirty();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Abono desde activo
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Abono a tarjeta desde activo',
                    style: TextStyle(
                      color: kTextSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        value: _abonoAssetName.isEmpty ? null : _abonoAssetName,
                        items: assetNames
                            .map(
                              (name) => DropdownMenuItem<String>(
                                value: name,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: kTextMain,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: assetNames.isEmpty
                            ? null
                            : (v) {
                                setState(() => _abonoAssetName = v ?? '');
                              },
                        decoration: InputDecoration(
                          hintText: assetNames.isEmpty
                              ? 'No hay activos disponibles'
                              : 'Activo de pago',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        dropdownColor: kSurface,
                        iconEnabledColor: kTextSoft,
                        style: const TextStyle(color: kTextMain),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _abonoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [ThousandsFormatter()],
                        style: const TextStyle(color: kTextMain, fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: const TextStyle(color: kTextSoft),
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(
                            color: kTextSoft,
                            fontSize: 13,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: assetNames.isEmpty
                            ? null
                            : () => _applyPayment(state),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 40),
                        ),
                        child: const Text('Abonar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}
