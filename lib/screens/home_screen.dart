import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/snie_service.dart';
import '../services/offline_queue.dart';
import 'nouveau_lot_screen.dart';
import 'transfert_screen.dart';
import 'mes_lots_screen.dart';
import 'login_screen.dart';

/// Écran principal : 3 onglets (Nouveau lot / Transfert / Mes lots)
/// + bandeau de synchronisation permanent si des opérations sont en file.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (SnieService.agent == null) SnieService.loadAgentProfile().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Au retour de l'app au premier plan : tentative de synchro automatique.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && OfflineQueue.length > 0) _sync();
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final (ok, ko) = await SnieService.synchroniser();
    setState(() => _syncing = false);
    if (mounted && (ok > 0 || ko > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Synchronisation : $ok réussie(s), $ko restante(s).')));
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = SnieService.agent;
    final pages = [
      NouveauLotScreen(onDone: () => setState(() {})),
      TransfertScreen(onDone: () => setState(() {})),
      const MesLotsScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: const [
          Text('SNIE', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 3)),
          Text(' ◆', style: TextStyle(color: SnieColors.gold)),
        ]),
        actions: [
          if (agent != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: Text('${agent['nom']}\n${agent['org']}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 10.5, color: SnieColors.dim)),
              ),
            ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout, size: 20)),
        ],
      ),
      body: Column(children: [
        if (OfflineQueue.length > 0)
          Material(
            color: SnieColors.panel2,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.cloud_off, color: SnieColors.amber, size: 20),
              title: Text('${OfflineQueue.length} opération(s) en attente de synchronisation',
                  style: const TextStyle(fontSize: 12.5)),
              trailing: TextButton(
                onPressed: _syncing ? null : _sync,
                child: Text(_syncing ? '…' : 'Synchroniser',
                    style: const TextStyle(color: SnieColors.lime)),
              ),
            ),
          ),
        Expanded(child: pages[_tab]),
      ]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: SnieColors.panel,
        indicatorColor: SnieColors.panel2,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_box_outlined), label: 'Nouveau lot'),
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Transfert'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Mes lots'),
        ],
      ),
    );
  }
}
