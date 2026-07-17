import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models.dart';
import '../theme.dart';
import '../services/snie_service.dart';
import '../services/location_service.dart';

/// SNIE·08 — Transfert / pesée de contrôle sur un lot existant.
/// C'est ici que le moteur de recoupement travaille : un écart > 4 % avec la
/// pesée précédente déclenchera l'alerte critique côté registre (trigger).
class TransfertScreen extends StatefulWidget {
  final VoidCallback onDone;
  const TransfertScreen({super.key, required this.onDone});
  @override
  State<TransfertScreen> createState() => _TransfertScreenState();
}

class _TransfertScreenState extends State<TransfertScreen> {
  final _kg = TextEditingController();
  List<LotResume>? _lots;
  Map<String, List<RefItem>>? _refs;
  LotResume? _lot;
  RefItem? _site;
  String _etape = etapesDb[1];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lots = await SnieService.mesLots();
      final refs = await SnieService.loadRefs();
      setState(() {
        _lots = lots;
        _refs = refs;
        _lot = lots.isNotEmpty ? lots.first : null;
        _site = refs['sites']!.isNotEmpty ? refs['sites']!.first : null;
        if (_lot != null) _etape = _prochaineEtape(_lot!);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Lots indisponibles (réseau requis au premier lancement).')));
      }
    }
  }

  String _prochaineEtape(LotResume l) {
    final i = etapesDb.indexOf(l.etape);
    return etapesDb[(i + 1).clamp(1, etapesDb.length - 1)];
  }

  Future<void> _submit() async {
    if (_lot == null) return;
    final kg = num.tryParse(_kg.text.replaceAll(',', '.'));
    if (kg == null || kg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Renseignez la pesée de contrôle.')));
      return;
    }
    setState(() => _busy = true);
    final pos = await LocationService.capture();
    final payload = {
      'lot_id': _lot!.dbId,
      'etape': _etape,
      'poids_kg': kg,
      'site_id': _site?.id,
      'horodatage_terrain': DateTime.now().toIso8601String(),
      'position': LocationService.toWkt(pos),
    };
    try {
      final direct = await SnieService.writeThroughQueue(
          'mouvement', payload, 'mob-${const Uuid().v4()}');
      // Pré-contrôle local informatif (le contrôle qui fait foi est le trigger serveur)
      final ecart = (kg - _lot!.poidsKg).abs() / _lot!.poidsKg * 100;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(direct
                ? (ecart > 4
                    ? 'Transfert enregistré — écart de ${ecart.toStringAsFixed(1)} % : une alerte va être levée par le registre.'
                    : 'Transfert enregistré, chaîne mise à jour.')
                : 'Hors-ligne : transfert mis en file.')));
        _kg.clear();
        widget.onDone();
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Refusé par le registre : $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Boîte de dialogue : créer un point de collecte (code attribué
  /// automatiquement) et le sélectionner immédiatement. Réseau requis.
  Future<void> _nouveauPointCollecte() async {
    final refs = _refs;
    if (refs == null) return;
    final nomCtrl = TextEditingController();
    RefItem? commune =
        refs['communes']!.isNotEmpty ? refs['communes']!.first : null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: SnieColors.panel,
          title: const Text('Nouveau point de collecte',
              style: TextStyle(fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nomCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Nom du point de collecte',
                  hintText: 'ex : Marché central — quai 2'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<RefItem>(
              value: commune,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Commune'),
              dropdownColor: SnieColors.panel2,
              items: refs['communes']!
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.nom)))
                  .toList(),
              onChanged: (v) => setDlg(() => commune = v),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Créer',
                    style: TextStyle(color: SnieColors.lime))),
          ],
        ),
      ),
    );
    if (ok != true || nomCtrl.text.trim().isEmpty) return;
    try {
      final item = await SnieService.creerPointCollecte(
          nomCtrl.text.trim(), commune?.id);
      setState(() {
        _refs!['sites']!.add(item);
        _site = item;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Point de collecte "${nomCtrl.text.trim()}" créé.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Création impossible (réseau requis) : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lots = _lots, refs = _refs;
    if (lots == null || refs == null) {
      return const Center(child: CircularProgressIndicator(color: SnieColors.jade));
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('TRANSFERT · PESÉE DE CONTRÔLE',
            style: TextStyle(fontSize: 11, letterSpacing: 2, color: SnieColors.gold)),
        const SizedBox(height: 14),
        DropdownButtonFormField<LotResume>(
          value: _lot,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Lot concerné'),
          dropdownColor: SnieColors.panel2,
          items: lots
              .map((l) => DropdownMenuItem(
                  value: l,
                  child: Text('${l.numero} · ${matiereFr(l.matiere)} · ${etapesFr[l.etape]}',
                      overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() {
            _lot = v;
            if (v != null) _etape = _prochaineEtape(v);
          }),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _etape,
          decoration: const InputDecoration(labelText: 'Nouvelle étape'),
          dropdownColor: SnieColors.panel2,
          items: etapesDb
              .sublist(1)
              .map((e) => DropdownMenuItem(value: e, child: Text(etapesFr[e]!)))
              .toList(),
          onChanged: (v) => setState(() => _etape = v!),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _kg,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
              labelText: 'Poids pesé à ce transfert (kg)',
              hintText: _lot != null ? 'pesée initiale : ${_lot!.poidsKg} kg' : null),
        ),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: DropdownButtonFormField<RefItem>(
              value: _site,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Site / point de collecte'),
              dropdownColor: SnieColors.panel2,
              items: refs['sites']!
                  .map((s) => DropdownMenuItem(
                      value: s, child: Text(s.nom, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _site = v),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Nouveau point de collecte',
            onPressed: _nouveauPointCollecte,
            icon: const Icon(Icons.add_circle_outline, color: SnieColors.lime),
          ),
        ]),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _busy || _lot == null ? null : _submit,
          child: Text(_busy ? 'Enregistrement…' : 'Enregistrer le transfert'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Chaque transfert ajoute une ligne au registre — rien n\'est jamais modifié. Un écart de pesée anormal met le lot en litige automatiquement.',
          style: TextStyle(fontSize: 11.5, color: SnieColors.faint),
        ),
      ],
    );
  }
}
