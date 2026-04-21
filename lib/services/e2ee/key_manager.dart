import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:oqs/oqs.dart' as oqs;
import 'package:pocketbase/pocketbase.dart';

import 'secure_storage.dart';

class KeyManager {
  final PocketBase pb;
  final String keyNamespace;
  final E2eeSecureStorage _storage;

  KeyManager({
    required this.pb,
    required this.keyNamespace,
    E2eeSecureStorage? storage,
  }) : _storage = storage ?? E2eeSecureStorage();

  Future<void> ensureUserKeys({required String userId}) async {
    // If secrets already exist locally, we consider keys established.
    final kyberSecretB64 = await _storage.readBase64(
      E2eeSecureStorage.kyberSecretKey(userId, namespace: keyNamespace),
    );
    final dilSecretB64 =
        await _storage.readBase64(
          E2eeSecureStorage.dilithiumSecretKey(userId, namespace: keyNamespace),
        );

    final userRecord = await pb.collection('users').getOne(userId);
    final hasUploadedKyber = userRecord.getStringValue('kyber_public_key', '').isNotEmpty;
    final hasUploadedDil = userRecord.getStringValue('dilithium_public_key', '').isNotEmpty;

    if (kyberSecretB64 != null &&
        dilSecretB64 != null &&
        hasUploadedKyber &&
        hasUploadedDil) {
      return;
    }

    final oqs.KEM? kem = oqs.KEM.create('ML-KEM-512');
    final oqs.Signature? sig = oqs.Signature.create('Dilithium2');
    if (kem == null || sig == null) {
      throw Exception('OQS algorithms unavailable on this platform');
    }

    try {
      final kemPair = kem.generateKeyPair();
      final sigPair = sig.generateKeyPair();

      await _storage.writeBase64(
        E2eeSecureStorage.kyberSecretKey(userId, namespace: keyNamespace),
        base64Encode(kemPair.secretKey),
      );
      await _storage.writeBase64(
        E2eeSecureStorage.dilithiumSecretKey(userId, namespace: keyNamespace),
        base64Encode(sigPair.secretKey),
      );

      final files = <http.MultipartFile>[
        http.MultipartFile.fromBytes(
          'kyber_public_key',
          Uint8List.fromList(kemPair.publicKey),
          filename: 'kyber_pub.bin',
        ),
        http.MultipartFile.fromBytes(
          'dilithium_public_key',
          Uint8List.fromList(sigPair.publicKey),
          filename: 'dilithium_pub.bin',
        ),
      ];

      await pb.collection('users').update(
        userId,
        body: {
          'key_version': 1,
          'key_rotated_at': DateTime.now().toUtc().toIso8601String(),
        },
        files: files,
      );
    } finally {
      kem.dispose();
      sig.dispose();
    }
  }
}

