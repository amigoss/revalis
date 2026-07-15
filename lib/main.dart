import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'theme.dart';
import 'services/offline_queue.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SnieConfig.supabaseUrl,
    anonKey: SnieConfig.supabaseAnonKey,
  );
  await OfflineQueue.load();
  runApp(const SnieApp());
}

class SnieApp extends StatelessWidget {
  const SnieApp({super.key});
  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return MaterialApp(
      title: 'SNIE Agent',
      debugShowCheckedModeBanner: false,
      theme: snieTheme(),
      home: session == null ? const LoginScreen() : const HomeScreen(),
    );
  }
}
