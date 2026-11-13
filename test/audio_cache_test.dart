import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/audio/data/audio_cache_native.dart';

void main() {
  test('native cache survives recreation, coalesces requests and separates signed URLs', () async {
    final directory = await Directory.systemTemp.createTemp(
      'lingoblob-audio-test-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((request) async {
      requests++;
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.add([1, 2, 3, 4]);
      await request.response.close();
    });
    final first = FileAudioCache(directory: () async => directory);
    final second = FileAudioCache(directory: () async => directory);
    addTearDown(() async {
      first.dispose();
      second.dispose();
      await server.close(force: true);
      final root = await Directory.systemTemp.resolveSymbolicLinks();
      final target = await directory.resolveSymbolicLinks();
      expect(
        target.startsWith(
          '$root${Platform.pathSeparator}lingoblob-audio-test-',
        ),
        isTrue,
      );
      await directory.delete(recursive: true);
    });
    final url = 'http://127.0.0.1:${server.port}/hello.mp3?version=1';
    final concurrent = await Future.wait([
      first.resolve(url),
      first.resolve(url),
    ]);
    expect(concurrent[0], concurrent[1]);
    expect(requests, 1);
    expect(await File.fromUri(Uri.parse(concurrent.first)).readAsBytes(), [
      1,
      2,
      3,
      4,
    ]);
    expect(await second.resolve(url), concurrent.first);
    expect(requests, 1);
    expect(
      await first.resolve(url.replaceAll('version=1', 'version=2')),
      isNot(concurrent.first),
    );
    expect(requests, 2);
    await expectLater(
      first.resolve('file:///untrusted.mp3'),
      throwsFormatException,
    );
  });
}
