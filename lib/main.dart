import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
import 'services/reminder_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FirebaseMessagingService.instance.initialize();
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadAndAutoApply();
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

    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
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
      ),
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
  bool _loadingReminder = true;
  bool _savingReminder = false;
  bool _reminderEnabled = true;
  int _reminderHour = 19;
  int _reminderMinute = 30;

  @override
  void initState() {
    super.initState();
    _loadReminderSettings();
  }

  Future<void> _loadReminderSettings() async {
    final settings = await ReminderNotificationService.instance
        .getDailyReminderSettings();
    if (!mounted) return;
    setState(() {
      _reminderEnabled = settings.enabled;
      _reminderHour = settings.hour;
      _reminderMinute = settings.minute;
      _loadingReminder = false;
    });
  }

  String _timeLabel(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(
      TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
  }

  String _scheduledAtLabel(BuildContext context, DateTime dateTime) {
    final localizations = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final isTomorrow = target.difference(today).inDays == 1;
    final dayLabel = isTomorrow
        ? 'manana'
        : localizations.formatFullDate(dateTime);
    final timeLabel = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(dateTime),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return '$dayLabel a las $timeLabel';
  }

  String _notificationErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('notifications-permission-denied')) {
      return 'Permiso de notificaciones denegado. Activalo en ajustes del telefono.';
    }
    if (message.contains('notifications-schedule-failed')) {
      return 'No se pudo programar en este dispositivo. Detalle: $message';
    }
    return 'No se pudo actualizar el recordatorio. Detalle: $message';
  }

  Future<void> _toggleReminder(bool enabled) async {
    if (_savingReminder) return;
    setState(() {
      _savingReminder = true;
      _reminderEnabled = enabled;
    });

    try {
      if (enabled) {
        final scheduledAt = await ReminderNotificationService.instance
            .scheduleDailyExpenseReminder(
              hour: _reminderHour,
              minute: _reminderMinute,
            );
        if (!mounted) return;
        if (scheduledAt != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Recordatorio activado y programado para ${_scheduledAtLabel(context, scheduledAt)}.',
              ),
            ),
          );
        }
      } else {
        await ReminderNotificationService.instance
            .disableDailyExpenseReminder();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recordatorio diario desactivado.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _reminderEnabled = !enabled);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_notificationErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _savingReminder = false);
      }
    }
  }

  Future<void> _pickReminderTime() async {
    if (_savingReminder) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );
    if (picked == null) return;

    setState(() {
      _reminderHour = picked.hour;
      _reminderMinute = picked.minute;
    });

    if (!_reminderEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hora guardada. Activa el recordatorio para notificar a las ${_timeLabel(context)}.',
          ),
        ),
      );
      return;
    }

    setState(() => _savingReminder = true);
    try {
      final scheduledAt = await ReminderNotificationService.instance
          .scheduleDailyExpenseReminder(
            hour: _reminderHour,
            minute: _reminderMinute,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scheduledAt == null
                ? 'Recordatorio reprogramado.'
                : 'Recordatorio reprogramado para ${_scheduledAtLabel(context, scheduledAt)}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_notificationErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _savingReminder = false);
      }
    }
  }

  Future<void> _sendTestNotification() async {
    if (_savingReminder) return;
    setState(() => _savingReminder = true);
    try {
      await ReminderNotificationService.instance.showInstantTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notificacion de prueba enviada. Revisa la barra de notificaciones.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_notificationErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _savingReminder = false);
      }
    }
  }

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
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x12000000),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kLine),
              ),
              child: _loadingReminder
                  ? const SizedBox(
                      height: 34,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kAccent,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Recordatorio diario',
                                style: TextStyle(
                                  color: kTextMain,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Switch(
                              value: _reminderEnabled,
                              onChanged: _savingReminder
                                  ? null
                                  : (v) => _toggleReminder(v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Todos los dias a las ${_timeLabel(context)}',
                                style: const TextStyle(
                                  color: kTextSoft,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _savingReminder
                                  ? null
                                  : _pickReminderTime,
                              icon: const PhosphorIcon(
                                PhosphorIconsLight.clock,
                                size: 16,
                              ),
                              label: const Text('Cambiar hora'),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _savingReminder
                                ? null
                                : _sendTestNotification,
                            icon: const PhosphorIcon(
                              PhosphorIconsLight.bellRinging,
                              size: 16,
                            ),
                            label: const Text('Probar notificacion ahora'),
                          ),
                        ),
                      ],
                    ),
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
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
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
