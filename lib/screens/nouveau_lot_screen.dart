import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models.dart';
import '../theme.dart';
import '../services/snie_service.dart';
import '../services/location_service.dart';

/// SNIE·08 — Création de lot à la pré-collecte.
/// Pesée + matière + origine ; GPS et horodatage capturés automatiquement.
class NouveauLotScreen extends StatefulWidget {
  final VoidCallback onDone;
  const NouveauLotScreen({super.key, required this.onDone});
  @override
  State<NouveauLotScreen> createState() => _NouveauLotScreenState();
}

class _NouveauLotScreenState extends State<NouveauLotScreen> {
  final _kg = TextEditingController();
  String _matiere = matieres.first;
  RefItem? _commune, _coop;
  Map<String, List<RefItem>>? _refs;
  String? _gpsLabel;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadRefs();
    _captureGps();
  }

  Future<void> _loadRefs() async {
    try {
      final r = await SnieService.loadRefs();
      setState(() {
        _refs = r;
        _commune = r['communes']!.isNotEmpty ? r['communes']!.first : null;
        _coop = r['cooperatives']!.isNotEmpty ? r['cooperatives']!.first : null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Référentiels indisponibles (première connexion réseau requise).')));
      }
    }
  }

  Future<void> _captureGps() async {
    final p = await LocationService.capture();
    if (mounted && p != null) {
      setState(() => _gpsLabel =
          '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}');
    }
  }

  Future<void> _submit() async {
    final kg = num.tryParse(_kg.text.replaceAll(',', '.'));
    if (kg == null || kg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Renseignez un poids valide.')));
      return;
    }
    setState(() => _busy = true);
    final pos = await LocationService.capture();
    final payload = {
      'matiere': _matiere,
      'poids_kg': kg,
      'commune_id': _commune?.id,
      'cooperative_id': _coop?.id,
      'horodatage_terrain': DateTime.now().toIso8601String(),
      'position': LocationService.toWkt(pos),
    };
    try {
      final direct = await SnieService.writeThroughQueue(
          'lot', payload, 'mob-${const Uuid().v4()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(direct
                ? 'Lot créé — pré-collecte enregistrée${pos != null ? " (GPS capturé)" : ""}.'
                : 'Hors-ligne : lot mis en file, il partira à la prochaine synchronisation.')));
        _kg.clear();
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Refusé par le registre : $e'),
            backgroundColor: SnieColors.panel2));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final refs = _refs;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('NOUVEAU LOT · PRÉ-COLLECTE',
            style: TextStyle(fontSize: 11, letterSpacing: 2, color: SnieColors.gold)),
        const SizedBox(height: 14),
        Row(children: [
          Icon(Icons.gps_fixed,
              size: 16, color: _gpsLabel != null ? SnieColors.ok : SnieColors.faint),
          const SizedBox(width: 8),
          Expanded(
              child: Text(_gpsLabel ?? 'GPS : capture en cours…',
                  style: const TextStyle(fontSize: 12, color: SnieColors.dim))),
          TextButton(onPressed: _captureGps, child: const Text('Recapturer')),
        ]),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _matiere,
          decoration: const InputDecoration(labelText: 'Matière'),
          dropdownColor: SnieColors.panel2,
          items: matieres.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => _matiere = v!),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _kg,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(labelText: 'Poids pesé (kg)', hintText: 'ex : 240'),
        ),
        const SizedBox(height: 14),
        if (refs != null) ...[
          DropdownButtonFormField<RefItem>(
            value: _commune,
            decoration: const InputDecoration(labelText: "Commune d'origine"),
            dropdownColor: SnieColors.panel2,
            items: refs['communes']!
                .map((c) => DropdownMenuItem(value: c, child: Text(c.nom)))
                .toList(),
            onChanged: (v) => setState(() => _commune = v),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<RefItem>(
            value: _coop,
            decoration: const InputDecoration(labelText: 'Coopérative'),
            dropdownColor: SnieColors.panel2,
            items: refs['cooperatives']!
                .map((c) => DropdownMenuItem(value: c, child: Text(c.nom)))
                .toList(),
            onChanged: (v) => setState(() => _coop = v),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: LinearProgressIndicator(color: SnieColors.jade, backgroundColor: SnieColors.panel2),
          ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _busy || refs == null ? null : _submit,
          child: Text(_busy ? 'Enregistrement…' : 'Créer le lot'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Le numéro de lot est attribué par le registre. Sans réseau, la création est mise en file et partira automatiquement.',
          style: TextStyle(fontSize: 11.5, color: SnieColors.faint),
        ),
      ],
    );
  }
}
