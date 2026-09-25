import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty || publishableKey.isEmpty) {
    runApp(const MissingConfigApp());
    return;
  }
  await Supabase.initialize(url: url, publishableKey: publishableKey);
  runApp(const TurneoApp());
}

class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: Text('Falta configurar Supabase'))),
  );
}
