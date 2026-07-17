import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';
import 'offline_queue.dart';

/// Couche d'accès au registre SNIE (Supabase).
/// Toutes les écritures passent par writeThroughQueue : direct si réseau,
/// file persistante sinon. Les lectures sont mises en cache local pour
/// que "Mes lots" et les référentiels restent consultables hors-ligne.
class SnieService {
  static final _sb = Supabase.instance.client;

  // ---------- PROFIL AGENT ----------
  static Map<String, dynamic>? agent; // {id, nom, role, org}

  static Future<bool> loadAgentProfile() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return false;
    final data = await _sb
        .from('agents')
        .select('id, nom, role, organisations(nom)')
        .eq('user_id', uid)
        .maybeSingle();
    if (data == null) return false;
    agent = {
      'id': data['id'],
      'nom': data['nom'],
      'role': data['role'],
      'org': data['organisations']?['nom'] ?? '',
    };
    return true;
  }

  // ---------- RÉFÉRENTIELS (avec cache hors-ligne) ----------
  static Future<Map<String, List<RefItem>>> loadRefs() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final results = await Future.wait([
        _sb.from('collectivites').select('id, nom').eq('niveau', 'commune').limit(200),
        _sb.from('organisations').select('id, nom, type')
            .inFilter('type', ['cooperative', 'particulier', 'entreprise']).limit(200),
        _sb.from('sites').select('id, code, nom').limit(200),
      ]);
      final refs = {
        'communes': (results[0] as List).map((j) => RefItem.fromJson(j)).toList(),
        'fournisseurs': (results[1] as List)
            .map((j) => RefItem(j['id'],
                '${j['nom']} — ${typesFournisseur[j['type']] ?? j['type']}'))
            .toList(),
        'sites': (results[2] as List)
            .map((j) => RefItem(j['id'], '${j['code']} — ${j['nom']}'))
            .toList(),
      };
      await prefs.setString('snie_refs_cache_v2', jsonEncode({
        for (final e in refs.entries)
          e.key: e.value.map((r) => {'id': r.id, 'nom': r.nom}).toList()
      }));
      return refs;
    } catch (_) {
      final raw = prefs.getString('snie_refs_cache_v2');
      if (raw == null) rethrow;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in j.entries)
          e.key: (e.value as List).map((x) => RefItem(x['id'], x['nom'])).toList()
      };
    }
  }

  // ---------- CRÉATION DE RÉFÉRENTIELS (réseau requis) ----------
  /// Nouveau fournisseur : particulier, coopérative ou entreprise.
  static Future<RefItem> creerFournisseur(String nom, String type) async {
    final j = await _sb
        .from('organisations')
        .insert({'nom': nom, 'type': type})
        .select('id, nom, type')
        .single();
    return RefItem(
        j['id'], '${j['nom']} — ${typesFournisseur[j['type']] ?? j['type']}');
  }

  /// Nouveau point de collecte (site de type point_apport).
  static Future<RefItem> creerPointCollecte(String nom, String? communeId) async {
    final code =
        'PC-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final j = await _sb
        .from('sites')
        .insert({
          'code': code,
          'nom': nom,
          'type': 'point_apport',
          'commune_id': communeId,
        })
        .select('id, code, nom')
        .single();
    return RefItem(j['id'], '${j['code']} — ${j['nom']}');
  }

  // ---------- MES LOTS (avec cache hors-ligne) ----------
  static Future<List<LotResume>> mesLots() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final data = await _sb
          .from('lots')
          .select('id, numero, matiere, poids_initial_kg, etape_courante, collectivites(nom)')
          .neq('etape_courante', 'produit_expedie')
          .order('cree_le', ascending: false)
          .limit(60);
      final lots = (data as List).map((j) => LotResume.fromJson(j)).toList();
      await prefs.setString(
          'snie_lots_cache', jsonEncode(lots.map((l) => l.toJson()).toList()));
      return lots;
    } catch (_) {
      final raw = prefs.getString('snie_lots_cache');
      if (raw == null) rethrow;
      return (jsonDecode(raw) as List)
          .map((j) => LotResume.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    }
  }

  // ---------- ÉCRITURES ----------
  static Future<void> _execCreateLot(Map<String, dynamic> p, String clientRef) async {
    final lot = await _sb.from('lots').insert({
      'matiere': p['matiere'],
      'poids_initial_kg': p['poids_kg'],
      'cooperative_id': p['cooperative_id'],
      'commune_id': p['commune_id'],
      'cree_par': agent!['id'],
      'cree_le_terrain': p['horodatage_terrain'],
    }).select('id').single();
    await _sb.from('mouvements').insert({
      'lot_id': lot['id'],
      'etape': 'pre_collecte',
      'agent_id': agent!['id'],
      'poids_kg': p['poids_kg'],
      'horodatage_terrain': p['horodatage_terrain'],
      'client_ref': clientRef,
      'position': p['position'],
    });
  }

  static Future<void> _execMouvement(Map<String, dynamic> p, String clientRef) async {
    await _sb.from('mouvements').insert({
      'lot_id': p['lot_id'],
      'etape': p['etape'],
      'site_id': p['site_id'],
      'agent_id': agent!['id'],
      'poids_kg': p['poids_kg'],
      'horodatage_terrain': p['horodatage_terrain'],
      'client_ref': clientRef,
      'position': p['position'],
    });
  }

  /// true = écrit en direct ; false = mis en file hors-ligne.
  static Future<bool> writeThroughQueue(String type, Map<String, dynamic> payload,
      String clientRef) async {
    try {
      type == 'lot'
          ? await _execCreateLot(payload, clientRef)
          : await _execMouvement(payload, clientRef);
      return true;
    } on PostgrestException catch (e) {
      // Erreur métier (RLS, contrainte...) : inutile de mettre en file, on la remonte.
      // Sauf 23505 (doublon client_ref) = rejeu déjà passé : on considère OK.
      if (e.code == '23505') return true;
      rethrow;
    } catch (_) {
      // Erreur réseau : file persistante.
      await OfflineQueue.enqueue(
          QueuedOp(type, payload, clientRef, DateTime.now()));
      return false;
    }
  }

  static Future<(int, int)> synchroniser() =>
      OfflineQueue.flush((op) => op.type == 'lot'
          ? _execCreateLot(op.payload, op.clientRef)
          : _execMouvement(op.payload, op.clientRef));
}
