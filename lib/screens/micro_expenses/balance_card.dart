import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../budget/available_to_spend.dart';

class MiniBalanceCard extends StatelessWidget {
  final AppState state;
  const MiniBalanceCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final isPositive = state.netWorth >= 0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.985, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kSurface, Color(0xFF0A1220), Color(0xFF090F1A)],
            stops: [0.0, 0.52, 1.0],
          ),
          border: Border.all(
            color: isPositive ? kLine : kDanger.withOpacity(0.26),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.34),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
            BoxShadow(
              color: kAccent.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _BalanceTexturePainter()),
              ),
              Positioned(
                top: -42,
                right: -28,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  children: [
                    Text(
                      state.monthName.isEmpty
                          ? 'Presupuesto Mensual'
                          : state.monthName,
                      style: const TextStyle(
                        color: kTextSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: state.netWorth,
                        end: state.netWorth,
                      ),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        formatCurrencyFull(value),
                        style: TextStyle(
                          color: isPositive
                              ? const Color(0xFF23D47E)
                              : const Color(0xFFFF6F7D),
                          fontSize: 41,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.3,
                          height: 0.95,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Balance neto',
                      style: TextStyle(color: kTextSoft, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: kSurfaceSoft.withOpacity(0.32),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kLineSoft),
                      ),
                      child: Row(
                        children: [
                          _BalTile(
                            label: 'Activos',
                            value: state.totalAssets,
                            color: kSuccess,
                          ),
                          _MiniDivider(),
                          _BalTile(
                            label: 'Gastos fijos',
                            value: state.totalLiabilitiesWithoutMicro,
                            color: kDanger,
                          ),
                          _MiniDivider(),
                          _BalTile(
                            label: 'Gastos diarios',
                            value: state.totalMicroExpenses,
                            color: kWarning,
                          ),
                        ],
                      ),
                    ),
                    AvailableToSpendStrip(state: state),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: kLine,
    );
  }
}

class _BalTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _BalTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            formatCurrency(value),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: kTextSoft, fontSize: 10.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BalanceTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.018)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 18.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        linePaint,
      );
    }

    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.035),
          Colors.transparent,
          Colors.transparent,
          Colors.white.withOpacity(0.02),
        ],
        stops: const [0.0, 0.3, 0.68, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sheenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
