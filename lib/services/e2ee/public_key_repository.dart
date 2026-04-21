import 'dart:typed_data';

import 'package:pocketbase/pocketbase.dart';

import 'models.dart';
import 'pb_file_downloader.dart';

class PublicKeyRepository {
  final PocketBase pb;
  final PbFileDownloader _downloader;

  PublicKeyRepository(this.pb) : _downloader = PbFileDownloader(pb);

  final Map<String, UserPublicKeys> _cache = {};

  void clearCacheForUser(String userId) {
    _cache.remove(userId);
  }

  Future<UserPublicKeys> fetchUserPublicKeys(String userId) async {
    final cached = _cache[userId];
    if (cached != null) return cached;

    final record = await pb.collection('users').getOne(userId);
    final kyberFilename = record.getStringValue('kyber_public_key', '');
    final dilithiumFilename = record.getStringValue('dilithium_public_key', '');

    if (kyberFilename.isEmpty || dilithiumFilename.isEmpty) {
      throw Exception('User $userId missing public keys');
    }

    final kyberPub = await _downloader.downloadFile(
      collection: 'users',
      recordId: userId,
      filename: kyberFilename,
    );
    final dilithiumPub = await _downloader.downloadFile(
      collection: 'users',
      recordId: userId,
      filename: dilithiumFilename,
    );

    final keys = UserPublicKeys(
      kyberPublicKey: Uint8List.fromList(kyberPub),
      dilithiumPublicKey: Uint8List.fromList(dilithiumPub),
    );
    _cache[userId] = keys;
    return keys;
  }
}

