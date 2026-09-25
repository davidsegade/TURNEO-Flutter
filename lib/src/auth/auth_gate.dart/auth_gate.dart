import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app.dart';
import '../data/turneo_repository.dart';
import '../models/turneo_models.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _subscription;
  final auth = Supabase.instance.client.auth;
  String? _uid;
  TurneoRepository? _repo;
  Future<AppUser>? _profile;
  bool _recovering = Uri.base.queryParameters['recovery'] == '1';
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncSession();
    _subscription = auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      setState(() {
        if (state.event == AuthChangeEvent.passwordRecovery) _recovering = true;
        if (state.event == AuthChangeEvent.signedOut) _recovering = false;
        _syncSession();
      });
    }, onError: (_) {
      if (mounted)
        setState(() =>
            _error = 'No se ha podido renovar la sesión. Vuelve a entrar.');
    });
  }

  void _syncSession() {
    final uid = auth.currentUser?.id;
    if (uid == _uid) return;
    _uid = uid;
    _error = null;
    _repo = uid == null ? null : TurneoRepository();
    _profile = _repo?.loadProfile();
  }

  Future<void> _logout() async {
    try {
      await auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      if (mounted)
        setState(() =>
            _error = 'No se ha podido cerrar la sesión. Inténtalo de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null)
      return LoginScreen(onSignedIn: () {
        if (mounted) setState(_syncSession);
      });
    if (_recovering)
      return PasswordScreen(onSaved: () => setState(() => _recovering = false));
    return FutureBuilder<AppUser>(
        future: _profile,
        builder: (context, snapshot) {
          if (_error != null || snapshot.hasError) {
            return Scaffold(
                body: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error ??
                                'No se ha podido verificar tu usuario de TURNEO. Comprueba la conexión y la asociación de tu cuenta.'),
                            TextButton(
                                onPressed: () => setState(() {
                                      _error = null;
                                      _profile = _repo!.loadProfile();
                                    }),
                                child: const Text('REINTENTAR')),
                            TextButton(
                                onPressed: _logout,
                                child: const Text('CERRAR SESIÓN')),
                          ],
                        ))));
          }
          if (!snapshot.hasData)
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          return CalendarScreen(
              key: ValueKey(_uid), repository: _repo!, onLogout: _logout);
        });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class PasswordScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const PasswordScreen({super.key, required this.onSaved});
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  String? error;
  Future<void> save() async {
    if (busy) return;
    if (password.text.length < 8 || password.text != confirmation.text) {
      setState(() =>
          error = 'Usa al menos 8 caracteres y repite la misma contraseña.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: password.text));
      if (mounted) widget.onSaved();
    } catch (_) {
      if (mounted)
        setState(() => error =
            'No se ha podido guardar. Solicita un nuevo enlace si ha caducado.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('TURNEO · Contraseña')),
      body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration:
                          const InputDecoration(labelText: 'Nueva contraseña')),
                  TextField(
                      controller: confirmation,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'Repite la contraseña')),
                  if (error != null) Text(error!),
                  FilledButton(
                      onPressed: busy ? null : save,
                      child: Text(busy ? 'GUARDANDO…' : 'GUARDAR CONTRASEÑA')),
                ]),
              ))));
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }
}
