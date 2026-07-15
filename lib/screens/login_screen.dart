import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/snie_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
          email: _email.text.trim(), password: _pass.text);
      final ok = await SnieService.loadAgentProfile();
      if (!ok) {
        setState(() => _error =
            "Compte valide mais aucun profil dans la table agents. Contactez l'administrateur.");
        await Supabase.instance.client.auth.signOut();
        return;
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Connexion impossible : vérifiez le réseau.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('SNIE',
                      style: TextStyle(
                          fontSize: 34, fontWeight: FontWeight.w800,
                          letterSpacing: 4, color: Colors.white)),
                  const Text(' ◆',
                      style: TextStyle(fontSize: 26, color: SnieColors.gold)),
                ]),
                const SizedBox(height: 4),
                const Text('AGENT DE TERRAIN · REVALIS DIGITAL',
                    style: TextStyle(
                        fontSize: 11, letterSpacing: 2, color: SnieColors.dim)),
                const SizedBox(height: 34),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _busy ? null : _login,
                  child: Text(_busy ? 'Connexion…' : 'Se connecter'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!,
                      style: const TextStyle(color: SnieColors.red, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
