import 'dart:convert';
import 'dart:typed_data';

import 'package:oqs/oqs.dart' as oqs;

class SignatureService {
  Uint8List buildSignableBytes({
    required int version,
    required String chatType,
    required int timestampMs,
    required String senderId,
    required String chatId,
    required Uint8List salt,
    required Uint8List nonce,
    required Uint8List ciphertext,
    required Uint8List authTag,
  }) {
    final b = BytesBuilder(copy: false);
    b.addByte(version);
    b.add(utf8.encode(chatType));
    b.add(utf8.encode(senderId));
    b.add(utf8.encode(chatId));
    b.add(_int64ToBytes(timestampMs));
    b.add(salt);
    b.add(nonce);
    b.add(ciphertext);
    b.add(authTag);
    return b.toBytes();
  }

  Uint8List sign({
    required Uint8List signableBytes,
    required Uint8List dilithiumSecretKey,
  }) {
    final oqs.Signature? sig = oqs.Signature.create('Dilithium2');
    if (sig == null) {
      throw Exception('Dilithium2 unavailable on this platform');
    }
    try {
      final out = sig.sign(signableBytes, dilithiumSecretKey);
      return Uint8List.fromList(out);
    } finally {
      sig.dispose();
    }
  }

  bool verify({
    required Uint8List signableBytes,
    required Uint8List signatureBytes,
    required Uint8List dilithiumPublicKey,
  }) {
    final oqs.Signature? sig = oqs.Signature.create('Dilithium2');
    if (sig == null) return false;
    try {
      return sig.verify(signableBytes, signatureBytes, dilithiumPublicKey);
    } finally {
      sig.dispose();
    }
  }

  Uint8List _int64ToBytes(int value) {
    final bd = ByteData(8);
    bd.setInt64(0, value, Endian.big);
    return bd.buffer.asUint8List();
  }
}

