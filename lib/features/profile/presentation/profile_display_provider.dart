import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

/// Read-only presentation projection; learning and sync providers are unchanged.
final profileDisplayProvider = StreamProvider<({String? name, int words})>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return db
      .customSelect(
        '''SELECT
    (SELECT display_name FROM local_profiles LIMIT 1) AS display_name,
    (SELECT COUNT(*) FROM word_progress WHERE deleted = 0) AS word_count''',
        readsFrom: {db.localProfiles, db.wordProgress},
      )
      .watchSingle()
      .map(
        (row) => (
          name: row.readNullable<String>('display_name'),
          words: row.read<int>('word_count'),
        ),
      );
});
