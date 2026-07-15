import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// FILE HORS-LIGNE PERSISTANTE — le cœur offline-first de l'application.
///
/// Chaque écriture (lot, mouvement) est d'abord tentée en direct ; en cas
/// d'échec réseau elle est sérialisée ici (shared_preferences) et survit à la
/// fermeture de l'app. L'idempotence est garantie par `client_ref` : la
/// contrainte UNIQUE (lot_id, etape, client_ref) du schéma absorbe les rejeux,
/// on peut donc synchroniser plusieurs fois sans doublon.
class QueuedOp {
  final String type;                 // 'lot' | 'mouvement'
  final Map<String, dynamic> payload;
  final String clientRef;
  final DateTime enqueuedAt;
  QueuedOp(this.type, this.payload, this.clientRef, this.enqueuedAt);

  Map<String, dynamic> toJson() => {
        't': type, 'p': payload, 'r': clientRef,
        'a': enqueuedAt.toIso8601String(),
      };
  factory QueuedOp.fromJson(Map<String, dynamic> j) => QueuedOp(
      j['t'], Map<String, dynamic>.from(j['p']), j['r'], DateTime.parse(j['a']));
}

class OfflineQueue {
  static const _key = 'snie_offline_queue_v1';
  static List<QueuedOp> _ops = [];
  static int get length => _ops.length;
  static List<QueuedOp> get ops => List.unmodifiable(_ops);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    _ops = (jsonDecode(raw) as List)
        .map((e) => QueuedOp.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_ops.map((o) => o.toJson()).toList()));
  }

  static Future<void> enqueue(QueuedOp op) async {
    _ops.add(op);
    await _save();
  }

  /// Rejoue la file dans l'ordre chronologique (un lot avant ses mouvements).
  /// `executor` lève une exception si l'écriture échoue -> l'op reste en file.
  static Future<(int ok, int ko)> flush(
      Future<void> Function(QueuedOp op) executor) async {
    int ok = 0;
    final remaining = <QueuedOp>[];
    for (final op in _ops) {
      try {
        await executor(op);
        ok++;
      } catch (_) {
        remaining.add(op);
      }
    }
    final ko = remaining.length;
    _ops = remaining;
    await _save();
    return (ok, ko);
  }
}
