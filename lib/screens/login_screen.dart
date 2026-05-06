import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  bool _loading = false;
  String? _error;

  String _friendlyError(Object e) {
    final message = e.toString().toLowerCase();
    if (message.contains('google-signin-misconfigured') ||
        message.contains('apiexception: 10')) {
      return 'Google Sign-In no esta configurado en Firebase para Android. Revisa SHA-1/SHA-256 y google-services.json.';
    }
    if (message.contains('sign in aborted')) {
      return 'Inicio de sesion cancelado.';
    }
    return 'Error al iniciar sesion. Intenta de nuevo.';
  }

  Future<void> _signInGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.signInWithGoogle();
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAnonymous() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.signInAnonymously();
    } catch (e) {
      setState(() => _error = 'Error. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [Color(0x2E3B82F6), Color(0xFF04060B)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Logo / título
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4E54FF), Color(0xFF7B61FF)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5B5FFF).withOpacity(0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const PhosphorIcon(
                    PhosphorIconsLight.wallet,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Finanzas Personales',
                  style: TextStyle(
                    color: kTextMain,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Controla tus gastos y ahorro mes a mes',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextSoft, fontSize: 15),
                ),
                const Spacer(),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kDanger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kDanger.withOpacity(0.4)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: kDanger, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_loading)
                  const CircularProgressIndicator(color: kAccent)
                else ...[
                  // Google
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _signInGoogle,
                      icon: const PhosphorIcon(
                        PhosphorIconsLight.signIn,
                        size: 20,
                      ),
                      label: const Text('Continuar con Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Anónimo
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _continueAnonymous,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kTextSoft,
                        side: const BorderSide(color: kLine),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Continuar sin cuenta'),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
