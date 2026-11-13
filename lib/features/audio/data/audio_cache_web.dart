import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;

import '../domain/audio_ports.dart';

AudioCache createAudioCache() => BrowserAudioCache();

/// Session cache backed by blob URLs; normal HTTP caching remains available too.
class BrowserAudioCache implements AudioCache {
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
  final _urls = <String, String>{};
  final _pending = <String, Future<String>>{};
  @override
  Future<String> resolve(String url) => _pending.putIfAbsent(
    url,
    () => _resolve(url).whenComplete(() {
      _pending.remove(url);
    }),
  );
  Future<String> _resolve(String url) async {
    if (_urls.containsKey(url)) return _urls[url]!;
    final uri = Uri.parse(url);
    if (!{'https', 'http'}.contains(uri.scheme) || !uri.hasAuthority) {
      throw const FormatException('Invalid audio URL');
    }
    final result = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final bytes = result.data;
    if (bytes == null || bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('Invalid audio clip size');
    }
    if (_urls.length >= 20) {
      web.URL.revokeObjectURL(_urls.remove(_urls.keys.first)!);
    }
    final blob = web.Blob(
      <JSAny>[Uint8List.fromList(bytes).toJS].toJS,
      web.BlobPropertyBag(
        type: result.headers.value('content-type') ?? 'audio/mpeg',
      ),
    );
    return _urls[url] = web.URL.createObjectURL(blob);
  }

  @override
  void dispose() {
    _dio.close(force: true);
    for (final url in _urls.values) {
      web.URL.revokeObjectURL(url);
    }
    _urls.clear();
  }
}
