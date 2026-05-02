import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/micro_expenses_screen.dart';
import 'screens/charts_screen.dart';
import 'screens/saved_budgets_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FinanzasApp());
}

class FinanzasApp extends StatelessWidget {
  const FinanzasApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return ChangeNotifierProvider(
      create: (_) => AppState(authService: authService),
      child: MaterialApp(
        title: 'Finanzas Personales',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: StreamBuilder<User?>(
          stream: authService.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: kAppBg,
                body: Center(child: CircularProgressIndicator(color: kAccent)),
              );
            }
            if (snapshot.hasData) {
              return const _HomeGateway();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

class _HomeGateway extends StatefulWidget {
  const _HomeGateway();

  @override
  State<_HomeGateway> createState() => _HomeGatewayState();
}

class _HomeGatewayState extends State<_HomeGateway> {
  late Future<bool> _checkOnboardingDone;

  @override
  void initState() {
    super.initState();
    _checkOnboardingDone = _getOnboardingStatus();
  }

  Future<bool> _getOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_done') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkOnboardingDone,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: kAppBg,
            body: Center(child: CircularProgressIndicator(color: kAccent)),
          );
        }
        if (snapshot.data == true) {
          return const HomeShell();
        }
        return OnboardingScreen(
          onComplete: () {
            setState(() {
              _checkOnboardingDone = _getOnboardingStatus();
            });
          },
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Presupuesto'),
    _NavItem(Icons.coffee_outlined, Icons.coffee, 'Gastos diarios'),
    _NavItem(Icons.bar_chart_outlined, Icons.bar_chart, 'Gráficos'),
    _NavItem(Icons.folder_outlined, Icons.folder, 'Historial'),
  ];

  static const List<Widget> _screens = [
    BudgetScreen(),
    MicroExpensesScreen(),
    ChartsScreen(),
    SavedBudgetsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFA050910),
        elevation: 0,
        title: Text(
          _navItems[_currentIndex].label,
          style: const TextStyle(color: kTextMain, fontWeight: FontWeight.w600, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: kTextSoft),
            onPressed: () => _showProfileSheet(context),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFA050910),
          border: Border(top: BorderSide(color: kLineSoft)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: kTextSoft,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: _navItems.asMap().entries.map((e) {
            return BottomNavigationBarItem(
              icon: Icon(e.value.icon),
              activeIcon: Icon(e.value.activeIcon),
              label: e.value.label,
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showProfileSheet(BuildContext context) {
    final appState = context.read<AppState>();
    final auth = appState.authService;
    final user = auth.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 28,
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              backgroundColor: kAccent.withOpacity(0.2),
              child: user?.photoURL == null ? const Icon(Icons.person, color: kAccent) : null,
            ),
            const SizedBox(height: 12),
            Text(
              user?.displayName ?? (auth.isAnonymous ? 'Usuario anónimo' : 'Usuario'),
              style: const TextStyle(color: kTextMain, fontWeight: FontWeight.w600, fontSize: 16),
            ),
            if (user?.email != null)
              Text(user!.email!, style: const TextStyle(color: kTextSoft, fontSize: 13)),
            const SizedBox(height: 20),
            if (auth.isAnonymous)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      final migrated = await appState.linkAnonymousWithGoogleAndMigrateBudgets();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            migrated > 0
                                ? 'Cuenta vinculada. Se migraron $migrated presupuestos.'
                                : 'Cuenta vinculada correctamente.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().contains('google-signin-misconfigured')
                                ? 'No se pudo vincular con Google. Revisa configuracion Firebase (SHA-1/SHA-256).'
                                : 'No se pudo vincular con Google. Intenta de nuevo.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('Vincular con Google'),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await auth.signOut();
                },
                icon: const Icon(Icons.logout, color: kDanger),
                label: const Text('Cerrar sesión', style: TextStyle(color: kDanger)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: kDanger)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
