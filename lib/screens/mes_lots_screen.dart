import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';
import '../services/snie_service.dart';

/// Liste des lots en cours (cache hors-ligne : reste consultable sans réseau).
class MesLotsScreen extends StatefulWidget {
  const MesLotsScreen({super.key});
  @override
  State<MesLotsScreen> createState() => _MesLotsScreenState();
}

class _MesLotsScreenState extends State<MesLotsScreen> {
  List<LotResume>? _lots;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await SnieService.mesLots();
      setState(() { _lots = l; _err = null; });
    } catch (e) {
      setState(() => _err = 'Aucune donnée disponible hors-ligne pour l’instant.');
    }
  }

  Color _chip(String etape) => etape == 'valorisation' || etape == 'tri'
      ? SnieColors.amber
      : etape == 'produit_expedie'
          ? SnieColors.ok
          : SnieColors.dim;

  @override
  Widget build(BuildContext context) {
    if (_err != null) return Center(child: Text(_err!, style: const TextStyle(color: SnieColors.dim)));
    final lots = _lots;
    if (lots == null) return const Center(child: CircularProgressIndicator(color: SnieColors.jade));
    return RefreshIndicator(
      color: SnieColors.lime,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: lots.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final l = lots[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SnieColors.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SnieColors.edge),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.numero,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 3),
                  Text('${l.matiere} · ${l.poidsKg} kg · ${l.commune}',
                      style: const TextStyle(fontSize: 12, color: SnieColors.dim)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _chip(l.etape).withOpacity(.5)),
                ),
                child: Text(etapesFr[l.etape] ?? l.etape,
                    style: TextStyle(fontSize: 10.5, color: _chip(l.etape))),
              ),
            ]),
          );
        },
      ),
    );
  }
}
