import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One TV write: what was done, the state before and after, and how to
/// undo it.
class JournalEntry {
  final String tvId;
  final DateTime time;
  final String op;
  final String target;
  final String before;
  final String after;
  final String? undoCommand;
  final bool ok;

  const JournalEntry({
    required this.tvId,
    required this.time,
    required this.op,
    required this.target,
    required this.before,
    required this.after,
    this.undoCommand,
    required this.ok,
  });

  Map<String, dynamic> toJson() => {
        'tvId': tvId,
        'time': time.toIso8601String(),
        'op': op,
        'target': target,
        'before': before,
        'after': after,
        'undo': undoCommand,
        'ok': ok,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        tvId: j['tvId'] as String,
        time: DateTime.parse(j['time'] as String),
        op: j['op'] as String,
        target: j['target'] as String? ?? '',
        before: j['before'] as String? ?? '',
        after: j['after'] as String? ?? '',
        undoCommand: j['undo'] as String?,
        ok: j['ok'] as bool? ?? false,
      );

  @override
  String toString() => '$op($target) $before -> $after ok=$ok';
}

/// Per-TV journal kept in shared_preferences, newest last, capped at
/// [maxEntries].
class Journal {
  static const maxEntries = 500;

  final Future<SharedPreferences> _prefs;

  Journal([Future<SharedPreferences>? prefs])
      : _prefs = prefs ?? SharedPreferences.getInstance();

  static String keyFor(String tvId) => 'journal.$tvId';

  Future<List<JournalEntry>> entries(String tvId) async {
    final raw = (await _prefs).getStringList(keyFor(tvId)) ?? const [];
    final out = <JournalEntry>[];
    for (final s in raw) {
      try {
        out.add(
          JournalEntry.fromJson(jsonDecode(s) as Map<String, dynamic>),
        );
      } on FormatException {
        // Skip corrupt rows.
      }
    }
    return out;
  }

  Future<void> add(JournalEntry e) => addAll([e]);

  Future<void> addAll(List<JournalEntry> list) async {
    if (list.isEmpty) return;
    final prefs = await _prefs;
    final byTv = <String, List<JournalEntry>>{};
    for (final e in list) {
      (byTv[e.tvId] ??= []).add(e);
    }
    for (final MapEntry(key: tvId, value: es) in byTv.entries) {
      final raw = [
        ...?prefs.getStringList(keyFor(tvId)),
        for (final e in es) jsonEncode(e.toJson()),
      ];
      final capped =
          raw.length > maxEntries ? raw.sublist(raw.length - maxEntries) : raw;
      await prefs.setStringList(keyFor(tvId), capped);
    }
  }

  Future<void> clear(String tvId) async => (await _prefs).remove(keyFor(tvId));
}
