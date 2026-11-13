import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/audio_ports.dart';

AudioCache createAudioCache() => FileAudioCache();

class FileAudioCache implements AudioCache {
  FileAudioCache({Dio? dio, Future<Directory> Function()? directory})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15))),
      _directory = directory ?? getTemporaryDirectory;
  final Dio _dio;
  final Future<Directory> Function() _directory;
  final _pending = <String, Future<String>>{};
  @override
  Future<String> resolve(String url) => _pending.putIfAbsent(
    url,
    () => _resolve(url).whenComplete(() {
      _pending.remove(url);
    }),
  );
  Future<String> _resolve(String url) async {
    final uri = Uri.parse(url);
    if (!{'https', 'http'}.contains(uri.scheme) || !uri.hasAuthority) {
      throw const FormatException('Invalid audio URL');
    }
    final folder = Directory('${(await _directory()).path}/lingoblob_audio');
    await folder.create(recursive: true);
    final extension = uri.path.split('.').last.toLowerCase();
    final suffix =
        {'mp3', 'm4a', 'aac', 'ogg', 'wav', 'webm'}.contains(extension)
        ? extension
        : 'mp3';
    final file = File(
      '${folder.path}/${sha256.convert(utf8.encode(url))}.$suffix',
    );
    if (await file.exists() && await file.length() > 0) {
      return file.uri.toString();
    }
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('Invalid audio clip size');
    }
    final temporary = File('${file.path}.part');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);
    return file.uri.toString();
  }

  @override
  void dispose() => _dio.close(force: true);
}
