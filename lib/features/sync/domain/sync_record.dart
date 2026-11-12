import '../../../core/utils/json_reader.dart';

enum SyncKind { stats, word, lesson, profile }

final class SyncCursor {
  const SyncCursor({this.timestamp = 0, this.revision = 0});
  final int timestamp;
  final int revision;
  String get isoTimestamp => DateTime.fromMicrosecondsSinceEpoch(
    timestamp,
    isUtc: true,
  ).toIso8601String();
}

final class SyncRecord {
  SyncRecord._(this.kind, this.id, this.updatedAt, JsonMap data)
    : data = Map.unmodifiable(data);
  final SyncKind kind;
  final String id;
  final int updatedAt;
  final JsonMap data;

  factory SyncRecord.fromJson(SyncKind kind, JsonMap json) {
    final value = json['updated_at'];
    final stamp = value is int
        ? value
        : DateTime.tryParse(value is String ? value : '')
              ?.microsecondsSinceEpoch;
    if (stamp == null) throw const FormatException('Invalid updated_at');
    if (stamp < 0) throw const FormatException('Invalid updated_at');
    String? date(String key, {bool optional = false}) {
      if (optional && json[key] == null) return null;
      final value = DateTime.tryParse(JsonReader.text(json, key));
      if (value == null) throw FormatException('Invalid $key');
      return value.toUtc().toIso8601String();
    }

    int count(String key) {
      final value = JsonReader.integer(json, key);
      if (value < 0) throw FormatException('Invalid $key');
      return value;
    }

    switch (kind) {
      case SyncKind.profile:
        final name = json['display_name'];
        if (name is! String || name.length > 120) {
          throw const FormatException('Invalid display_name');
        }
        return SyncRecord._(kind, 'profile', stamp, {'display_name': name});
      case SyncKind.stats:
        return SyncRecord._(kind, 'stats', stamp, {
          'xp': count('xp'),
          'streak': count('streak'),
          'last_active_date': date('last_active_date', optional: true),
        });
      case SyncKind.word:
        final ease = json['ease_factor'];
        if (ease is! num || !ease.isFinite || ease < 1.3) {
          throw const FormatException('Invalid ease_factor');
        }
        return SyncRecord._(kind, JsonReader.text(json, 'word_id'), stamp, {
          'ease_factor': ease.toDouble(),
          'interval_days': count('interval_days'),
          'repetitions': count('repetitions'),
          'due_date': date('due_date'),
        });
      case SyncKind.lesson:
        final completed = json['completed'];
        final score = count('best_score');
        if (completed is! bool || score > 100) {
          throw const FormatException('Invalid lesson progress');
        }
        return SyncRecord._(kind, JsonReader.text(json, 'lesson_id'), stamp, {
          'completed': completed,
          'best_score': score,
          'completed_at': date('completed_at', optional: true),
        });
    }
  }

  JsonMap toJson() => {
    if (kind == SyncKind.word) 'word_id': id,
    if (kind == SyncKind.lesson) 'lesson_id': id,
    ...data,
    'updated_at': updatedAt,
  };

  JsonMap toRemoteJson(String userId) => {
    ...toJson(),
    'user_id': userId,
    'updated_at': DateTime.fromMicrosecondsSinceEpoch(
      updatedAt,
      isUtc: true,
    ).toIso8601String(),
  };
}

final class SyncSnapshot {
  SyncSnapshot(Iterable<SyncRecord> records, {this.cursor = const SyncCursor()})
    : records = List.unmodifiable(records);
  final List<SyncRecord> records;
  final SyncCursor cursor;

  factory SyncSnapshot.fromJson(JsonMap json, {required String userId}) {
    if (json['schema_version'] != 2 || json['user_id'] != userId) {
      throw const FormatException('Sync response owner or version mismatch');
    }
    final timestamp = DateTime.tryParse(
      JsonReader.text(json, 'last_synced_at'),
    );
    final revision = JsonReader.integer(json, 'revision');
    if (timestamp == null ||
        timestamp.microsecondsSinceEpoch < 0 ||
        revision < 0) {
      throw const FormatException('Invalid sync cursor');
    }
    SyncRecord record(SyncKind kind, Object? value) {
      final row = JsonReader.object(value, kind.name);
      if (row['user_id'] != userId) {
        throw const FormatException('Sync row owner mismatch');
      }
      return SyncRecord.fromJson(kind, row);
    }

    return SyncSnapshot(
      [
        if (json['profile'] != null) record(SyncKind.profile, json['profile']),
        if (json['stats'] != null) record(SyncKind.stats, json['stats']),
        for (final value in JsonReader.list(json, 'words'))
          record(SyncKind.word, value),
        for (final value in JsonReader.list(json, 'lessons'))
          record(SyncKind.lesson, value),
      ],
      cursor: SyncCursor(
        timestamp: timestamp.microsecondsSinceEpoch,
        revision: revision,
      ),
    );
  }
}

/// The remote value wins exact timestamp ties on every device.
bool remoteWins(int? localTimestamp, int remoteTimestamp) =>
    localTimestamp == null || remoteTimestamp >= localTimestamp;
