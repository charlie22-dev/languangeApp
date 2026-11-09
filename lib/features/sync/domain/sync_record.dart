import '../../../core/utils/json_reader.dart';

enum SyncKind { stats, word, lesson }

final class SyncRecord {
  SyncRecord._(this.kind, this.id, this.updatedAt, JsonMap data)
    : data = Map.unmodifiable(data);
  final SyncKind kind;
  final String id;
  final int updatedAt;
  final JsonMap data;

  factory SyncRecord.fromJson(SyncKind kind, JsonMap json) {
    final stamp = JsonReader.integer(json, 'updated_at');
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
}

final class SyncSnapshot {
  SyncSnapshot(Iterable<SyncRecord> records)
    : records = List.unmodifiable(records);
  final List<SyncRecord> records;

  factory SyncSnapshot.fromJson(JsonMap json, {required String userId}) {
    if (json['schema_version'] != 1 || json['user_id'] != userId) {
      throw const FormatException('Sync response owner or version mismatch');
    }
    return SyncSnapshot([
      if (json['stats'] != null)
        SyncRecord.fromJson(
          SyncKind.stats,
          JsonReader.object(json['stats'], 'stats'),
        ),
      for (final value in JsonReader.list(json, 'words'))
        SyncRecord.fromJson(SyncKind.word, JsonReader.object(value, 'word')),
      for (final value in JsonReader.list(json, 'lessons'))
        SyncRecord.fromJson(
          SyncKind.lesson,
          JsonReader.object(value, 'lesson'),
        ),
    ]);
  }

  JsonMap get payload => {
    'p_stats': records
        .where((row) => row.kind == SyncKind.stats)
        .firstOrNull
        ?.toJson(),
    'p_words': records
        .where((row) => row.kind == SyncKind.word)
        .map((row) => row.toJson())
        .toList(),
    'p_lessons': records
        .where((row) => row.kind == SyncKind.lesson)
        .map((row) => row.toJson())
        .toList(),
  };
}

/// The remote value wins exact timestamp ties on every device.
bool remoteWins(int? localTimestamp, int remoteTimestamp) =>
    localTimestamp == null || remoteTimestamp >= localTimestamp;
