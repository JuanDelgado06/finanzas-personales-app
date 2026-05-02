import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBg,
      body: PageView(
        controller: _pageController,
        onPageChanged: (page) {
          setState(() => _currentPage = page);
        },
        children: [
          _OnboardingPage(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Tu presupuesto personal',
            subtitle: 'Controla activos, gastos y deudas en un solo lugar',
            description: 'Crea presupuestos mensuales para organizar tu dinero y tomar decisiones financieras mejores.',
          ),
          _OnboardingPage(
            icon: Icons.coffee_outlined,
            title: 'Detecta fugas de dinero',
            subtitle: 'Registra gastos diarios',
            description: 'Esos cafés pequeños suman. Controla tus gastos cotidianos para ver dónde se va realmente tu dinero.',
          ),
          _OnboardingPage(
            icon: Icons.bar_chart_outlined,
            title: 'Visualiza tu progreso',
            subtitle: 'Gráficos y análisis',
            description: 'Descubre tus patrones de gasto, categorías principales y compara mes a mes.',
          ),
        ],
      ),
      bottomSheet: Container(
        color: const Color(0xFA050910),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == i ? kAccent : kLine,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kLine),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Atrás', style: TextStyle(color: kTextSoft)),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentPage == 2
                          ? _completeOnboarding
                          : () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                      child: Text(_currentPage == 2 ? 'Empezar' : 'Siguiente'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4E54FF), Color(0xFF7B61FF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B5FFF).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kTextMain,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kTextSoft,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
