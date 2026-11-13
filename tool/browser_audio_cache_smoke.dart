// Compile with `dart compile js` and serve next to a 4-byte clip.wav fixture.
// Run on an isolated origin; this checks HTTP/blob caching and never requests a mic.
import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:myapp/features/audio/data/audio_cache_web.dart';

Future<void> main() async {
  final cache = BrowserAudioCache();
  try {
    final source = Uri.base.resolve('clip.wav').toString();
    final urls = await Future.wait([
      cache.resolve(source),
      cache.resolve(source),
    ]);
    if (urls.first != urls.last || !urls.first.startsWith('blob:')) {
      throw StateError('Browser did not reuse its cached blob');
    }
    final response = await web.window.fetch(urls.first.toJS).toDart;
    final data = await response.arrayBuffer().toDart;
    if (data.toDart.lengthInBytes != 4) {
      throw StateError('Cached audio bytes changed');
    }
    web.console.log('BROWSER_AUDIO_CACHE_PASS'.toJS);
  } catch (error) {
    web.console.error('BROWSER_AUDIO_CACHE_FAIL: $error'.toJS);
    rethrow;
  } finally {
    cache.dispose();
  }
} 

