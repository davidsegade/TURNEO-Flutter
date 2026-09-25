import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const apiKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url != 'https://iiaxbriosudkmhsqvksn.supabase.co' ||
      !apiKey.startsWith('sb_publishable_') ||
      apiKey != apiKey.trim()) {
    runApp(const ConfigErrorApp());
    return;
  }
  try {
    await Supabase.initialize(url: url, publishableKey: apiKey, debug: false);
    runApp(const TurneoApp());
  } catch (_) {
    runApp(const ConfigErrorApp());
  }
}

class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TURNEO',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const Scaffold(
            body: Center(
                child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'No se ha podido iniciar TURNEO. Revisa la conexión y vuelve a abrir la aplicación.'),
        ))),
      );
}
