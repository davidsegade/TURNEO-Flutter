import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  const LoginScreen({super.key, required this.onSignedIn});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;
  String? info;

  Future<void> login() async {
    setState(() { busy = true; error = null; info = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
      widget.onSignedIn();
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'No se ha podido iniciar sesión. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    final address = email.text.trim();
    if (address.isEmpty) {
      setState(() {
        error = 'Escribe primero tu email.';
        info = null;
      });
      return;
    }
    setState(() { busy = true; error = null; info = null; });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(address);
      if (mounted) {
        setState(() => info = 'Te hemos enviado un correo para recuperar la contraseña.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'No se ha podido enviar el correo de recuperación.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.calendar_month_rounded, size: 64),
                const SizedBox(height: 18),
                const Text('TURNEO', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Acceso al cuadrante', textAlign: TextAlign.center),
                const SizedBox(height: 28),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => login(),
                  decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: busy ? null : resetPassword,
                    child: const Text('HE OLVIDADO MI CONTRASEÑA'),
                  ),
                ),
                if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
                if (info != null) Text(info!, style: const TextStyle(color: Colors.greenAccent)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy ? null : login,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(busy ? 'ESPERA…' : 'ENTRAR'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }
}
