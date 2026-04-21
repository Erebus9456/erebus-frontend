import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

class PbFileDownloader {
  final PocketBase pb;

  PbFileDownloader(this.pb);

  final Map<String, Uint8List> _cache = {};

  Uint8List? getCachedBytes(String cacheKey) => _cache[cacheKey];

  void cacheBytes(String cacheKey, Uint8List bytes) {
    _cache[cacheKey] = bytes;
  }

  Future<Uint8List> downloadFile({
    required String collection,
    required String recordId,
    required String filename,
  }) async {
    final cacheKey = '$collection/$recordId/$filename';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final url = Uri.parse('${pb.baseUrl}/api/files/$collection/$recordId/$filename');
    final headers = <String, String>{};
    final token = pb.authStore.token;
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final resp = await http.get(url, headers: headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Failed to download file: $collection/$recordId/$filename (HTTP ${resp.statusCode})');
    }

    final bytes = Uint8List.fromList(resp.bodyBytes);
    _cache[cacheKey] = bytes;
    return bytes;
  }
}

