import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final directory = Directory('build/performance');
    await directory.create(recursive: true);
    await File('${directory.path}/lesson_flow.json')
        .writeAsString(jsonEncode(data));
  },
);
