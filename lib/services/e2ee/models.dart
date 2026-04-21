import 'dart:typed_data';

class UserPublicKeys {
  final Uint8List kyberPublicKey;
  final Uint8List dilithiumPublicKey;

  const UserPublicKeys({
    required this.kyberPublicKey,
    required this.dilithiumPublicKey,
  });
}

class DecryptedAttachment {
  final String filename;
  final String? mimeType;
  final Uint8List bytes;

  const DecryptedAttachment({
    required this.filename,
    required this.bytes,
    this.mimeType,
  });
}

class DecryptedPayload {
  final int version;
  final String content;
  final String? replyToId;
  final List<DecryptedAttachment> attachments;

  const DecryptedPayload({
    required this.version,
    required this.content,
    required this.attachments,
    this.replyToId,
  });
}

class DecryptedMessageView {
  final String id;
  final String senderId;
  final DateTime created;
  final bool isVerified;

  final String content;
  final String? replyToId;
  final List<DecryptedAttachment> attachments;

  const DecryptedMessageView({
    required this.id,
    required this.senderId,
    required this.created,
    required this.isVerified,
    required this.content,
    required this.attachments,
    this.replyToId,
  });
}

class EncryptedForRecipient {
  final Uint8List kemCiphertext;
  final Uint8List hkdfSalt;
  final Uint8List xc20Nonce;
  final Uint8List ciphertext;
  final Uint8List authTag;

  const EncryptedForRecipient({
    required this.kemCiphertext,
    required this.hkdfSalt,
    required this.xc20Nonce,
    required this.ciphertext,
    required this.authTag,
  });
}

