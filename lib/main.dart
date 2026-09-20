import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
import 'services/firebase_messaging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FirebaseMessagingService.instance.initialize();
  await _restoreSession();
  runApp(const FinanzasApp());
}

const _kHadSessionKey = 'had_auth_session';

/// En Android, authStateChanges puede emitir un null inicial (y currentUser
/// seguir en null) mientras Firebase restaura la sesión persistida. Si en el
/// último uso había sesión, esperamos al usuario real antes de mostrar UI para
/// no caer en el login. El flag se limpia solo con un signOut explícito.
Future<void> _restoreSession() async {
  final prefs = await SharedPreferences.getInstance();
  final auth = FirebaseAuth.instance;
  if ((prefs.getBool(_kHadSessionKey) ?? false) && auth.currentUser == null) {
    try {
      await auth
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Sin red/sesión inválida: se muestra el login.
    }
    // Firebase no recuperó la sesión (en algunos Android se pierde al cerrar
    // la app). Si el usuario usaba Google, la cuenta sigue en el dispositivo:
    // reingresamos en silencio, sin mostrar selector de cuenta.
    if (auth.currentUser == null) {
      try {
        final g = await GoogleSignIn().signInSilently();
        if (g != null) {
          final ga = await g.authentication;
          await auth.signInWithCredential(GoogleAuthProvider.credential(
            accessToken: ga.accessToken,
            idToken: ga.idToken,
          ));
        }
      } catch (e) {
        debugPrint('Silent Google sign-in failed: $e');
      }
    }
  }
  debugPrint('Auth restore: currentUser=${auth.currentUser?.uid}');
  auth.authStateChanges().listen((u) {
    if (u != null) prefs.setBool(_kHadSessionKey, true);
  });
}

class FinanzasApp extends StatelessWidget {
  const FinanzasApp({super.key});

  static final AuthService _authService = FirebaseAuthService();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(authService: _authService),
      child: MaterialApp(
        title: 'Finanzas Personales',
        scaffoldMessengerKey: FirebaseMessagingService.messengerKey,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'CO'),
          Locale('es'),
          Locale('en'),
        ],
        home: _AuthGate(authService: _authService),
      ),
    );
  }
}

/// Decide entre login y app según la sesión, y muestra una pantalla de
/// transición breve cuando el usuario inicia o cierra sesión para que el
/// cambio se note (además reconstruye la app con el usuario nuevo).
class _AuthGate extends StatefulWidget {
  final AuthService authService;
  const _AuthGate({required this.authService});

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  StreamSubscription<User?>? _sub;
  Timer? _timer;
  String? _uid;
  String? _transitionMessage;

  @override
  void initState() {
    super.initState();
    _uid = widget.authService.currentUser?.uid;
    _sub = widget.authService.authStateChanges.listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    final newUid = user?.uid;
    if (newUid == _uid) return;
    final signedIn = newUid != null;
    setState(() {
      _uid = newUid;
      _transitionMessage = signedIn ? 'Iniciando sesión…' : 'Cerrando sesión…';
    });
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _transitionMessage = null);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // currentUser es la fuente de verdad (ver _restoreSession): el primer
    // evento de authStateChanges en Android puede llegar como null.
    final Widget child;
    if (_transitionMessage != null) {
      child = Scaffold(
        key: const ValueKey('auth-transition'),
        backgroundColor: kAppBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: kAccent),
              const SizedBox(height: 20),
              Text(
                _transitionMessage!,
                style: const TextStyle(color: kTextSoft, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    } else if (widget.authService.currentUser != null) {
      child = _HomeGateway(key: ValueKey('home-$_uid'));
    } else {
      child = const LoginScreen(key: ValueKey('login'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: child,
    );
  }
}

class _HomeGateway extends StatefulWidget {
  const _HomeGateway({super.key});

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadAndAutoApply();
      final uid = context.read<AppState>().authService.currentUser?.uid;
      if (uid != null) FirebaseMessagingService.instance.onUserSignedIn(uid);
    });
  }

  static const List<_NavItem> _navItems = [
    _NavItem(
      PhosphorIconsLight.coffee,
      PhosphorIconsLight.coffee,
      'Gastos diarios',
    ),
    _NavItem(
      PhosphorIconsLight.wallet,
      PhosphorIconsLight.piggyBank,
      'Presupuesto',
    ),
    _NavItem(
      PhosphorIconsLight.chartPieSlice,
      PhosphorIconsLight.chartBar,
      'Gráficos',
    ),
    _NavItem(
      PhosphorIconsLight.folder,
      PhosphorIconsLight.folderOpen,
      'Historial',
    ),
  ];

  static const List<Widget> _screens = [
    MicroExpensesScreen(),
    BudgetScreen(),
    ChartsScreen(),
    SavedBudgetsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isLoadingMonth = context.watch<AppState>().isLoadingMonth;
    final showAppBar = _currentIndex != 3; // No mostrar AppBar en la pantalla de historial

    return Scaffold(
      backgroundColor: kAppBg,
      appBar: showAppBar ? AppBar(
        backgroundColor: const Color(0xFA050910),
        elevation: 0,
        title: Text(
          _navItems[_currentIndex].label,
          style: const TextStyle(
            color: kTextMain,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const PhosphorIcon(
              PhosphorIconsLight.userCircle,
              color: kTextSoft,
            ),
            onPressed: () => _showProfileSheet(context),
          ),
        ],
      ) : null,
      body: isLoadingMonth
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : _screens[_currentIndex],
      bottomNavigationBar: _PillNavBar(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }

  void _showProfileSheet(BuildContext context) {
    final appState = context.read<AppState>();
    final auth = appState.authService;
    final user = auth.currentUser;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProfileSheet(appState: appState, user: user),
    );
  }
}

class _ProfileSheet extends StatefulWidget {
  final AppState appState;
  final User? user;

  const _ProfileSheet({required this.appState, required this.user});

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  @override
  Widget build(BuildContext context) {
    final auth = widget.appState.authService;
    final user = widget.user;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 28,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              backgroundColor: kAccent.withOpacity(0.2),
              child: user?.photoURL == null
                  ? const PhosphorIcon(PhosphorIconsLight.user, color: kAccent)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              user?.displayName ??
                  (auth.isAnonymous ? 'Usuario anónimo' : 'Usuario'),
              style: const TextStyle(
                color: kTextMain,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            if (user?.email != null)
              Text(
                user!.email!,
                style: const TextStyle(color: kTextSoft, fontSize: 13),
              ),
            const SizedBox(height: 12),
            if (auth.isAnonymous)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      final migrated = await widget.appState
                          .linkAnonymousWithGoogleAndMigrateBudgets();
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
                  icon: const PhosphorIcon(PhosphorIconsLight.link),
                  label: const Text('Vincular con Google'),
                ),
              ),
            const SizedBox(height: 8),
            if (kDebugMode)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _runNotificationTest(context),
                  icon: const PhosphorIcon(PhosphorIconsLight.bell),
                  label: const Text('Probar notificaciones'),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  FirebaseMessagingService.instance.onUserSignedOut();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(_kHadSessionKey, false);
                  await auth.signOut();
                },
                icon: const PhosphorIcon(
                  PhosphorIconsLight.signOut,
                  color: kDanger,
                ),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(color: kDanger),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kDanger),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

Future<void> _runNotificationTest(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final report = FirebaseMessagingService.instance.diagnose();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kSurface,
      title: const Text('Prueba de notificaciones'),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<String>(
          future: report,
          builder: (_, snap) => SingleChildScrollView(
            child: snap.hasData
                ? SelectableText(
                    snap.data!,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  )
                : const Center(child: CircularProgressIndicator(color: kAccent)),
          ),
        ),
      ),
      actions: [TextButton(onPressed: navigator.pop, child: const Text('Cerrar'))],
    ),
  );
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _PillNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;
  const _PillNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFA050910),
        border: Border(top: BorderSide(color: kLineSoft)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: items.asMap().entries.map((e) {
              final isActive = e.key == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(e.key),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? kAccent.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(
                          isActive ? e.value.activeIcon : e.value.icon,
                          color: isActive ? kAccent : kTextSoft,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.value.label,
                          style: TextStyle(
                            color: isActive ? kAccent : kTextSoft,
                            fontSize: 11,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
