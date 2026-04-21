import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:oqs/oqs.dart' as oqs;

import 'models.dart';
import 'payload_codec.dart';
import 'pb_file_downloader.dart';

class MessageCrypto {
  final PbFileDownloader downloader;
  final PayloadCodec payloadCodec;

  MessageCrypto({
    required this.downloader,
    PayloadCodec? payloadCodec,
  }) : payloadCodec = payloadCodec ?? PayloadCodec();

  final _algo = Xchacha20.poly1305Aead();

  Uint8List randomSalt32() => Uint8List.fromList(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );

  List<int> buildAad({
    required String chatType,
    required String chatId,
    required int timestampMs,
  }) {
    return utf8.encode('v1|$chatType|$chatId|$timestampMs');
  }

  Future<EncryptedForRecipient> encryptForRecipient({
    required Uint8List recipientKyberPublicKey,
    required Uint8List payloadBlob,
    required Uint8List salt,
    required Uint8List nonce,
    required List<int> aad,
  }) async {
    final oqs.KEM? kem = oqs.KEM.create('ML-KEM-512');
    if (kem == null) {
      throw Exception('ML-KEM-512 unavailable on this platform');
    }
    try {
      final enc = kem.encapsulate(recipientKyberPublicKey);
      final sharedSecret = Uint8List.fromList(enc.sharedSecret);

      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
      final sessionKeyObj = await hkdf.deriveKey(
        secretKey: SecretKey(sharedSecret),
        nonce: salt,
        info: utf8.encode('pqc-protocol-v1'),
      );
      final sessionKeyBytes = Uint8List.fromList(await sessionKeyObj.extractBytes());

      final secretBox = await _algo.encrypt(
        payloadBlob,
        secretKey: SecretKey(sessionKeyBytes),
        nonce: nonce,
        aad: aad,
      );

      // best-effort zeroization
      sharedSecret.fillRange(0, sharedSecret.length, 0);
      sessionKeyBytes.fillRange(0, sessionKeyBytes.length, 0);

      return EncryptedForRecipient(
        kemCiphertext: Uint8List.fromList(enc.ciphertext),
        hkdfSalt: Uint8List.fromList(salt),
        xc20Nonce: Uint8List.fromList(nonce),
        ciphertext: Uint8List.fromList(secretBox.cipherText),
        authTag: Uint8List.fromList(secretBox.mac.bytes),
      );
    } finally {
      kem.dispose();
    }
  }

  Future<DecryptedPayload> decryptFromRecordFiles({
    required String recordId,
    required String kemCiphertextFilename,
    required String hkdfSaltFilename,
    required String nonceFilename,
    required String ciphertextFilename,
    required String authTagFilename,
    required Uint8List kyberSecretKey,
    required List<int> aad,
  }) async {
    final kemCt = await downloader.downloadFile(
      collection: 'messages',
      recordId: recordId,
      filename: kemCiphertextFilename,
    );
    final salt = await downloader.downloadFile(
      collection: 'messages',
      recordId: recordId,
      filename: hkdfSaltFilename,
    );
    final nonce = await downloader.downloadFile(
      collection: 'messages',
      recordId: recordId,
      filename: nonceFilename,
    );
    final ciphertext = await downloader.downloadFile(
      collection: 'messages',
      recordId: recordId,
      filename: ciphertextFilename,
    );
    final authTag = await downloader.downloadFile(
      collection: 'messages',
      recordId: recordId,
      filename: authTagFilename,
    );

    final oqs.KEM? kem = oqs.KEM.create('ML-KEM-512');
    if (kem == null) {
      throw Exception('ML-KEM-512 unavailable on this platform');
    }
    Uint8List ss;
    try {
      final shared = kem.decapsulate(kemCt, kyberSecretKey);
      ss = Uint8List.fromList(shared);
    } finally {
      kem.dispose();
    }

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final sessionKeyObj = await hkdf.deriveKey(
      secretKey: SecretKey(ss),
      nonce: salt,
      info: utf8.encode('pqc-protocol-v1'),
    );
    final sessionKeyBytes = Uint8List.fromList(await sessionKeyObj.extractBytes());

    final plain = await _algo.decrypt(
      SecretBox(
        ciphertext,
        nonce: nonce,
        mac: Mac(authTag),
      ),
      secretKey: SecretKey(sessionKeyBytes),
      aad: aad,
    );

    // best-effort zeroization
    ss.fillRange(0, ss.length, 0);
    sessionKeyBytes.fillRange(0, sessionKeyBytes.length, 0);

    return payloadCodec.decode(Uint8List.fromList(plain));
  }
}
