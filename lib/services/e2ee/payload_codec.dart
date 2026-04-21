import 'dart:convert';
import 'dart:typed_data';

import 'models.dart';

class PayloadCodec {
  static const int currentVersion = 1;

  Uint8List encode({
    required String content,
    required String? replyToId,
    required List<DecryptedAttachment> attachments,
  }) {
    final map = <String, dynamic>{
      'v': currentVersion,
      'content': content,
      if (replyToId != null) 'reply_to': replyToId,
      'attachments': attachments
          .map(
            (a) => <String, dynamic>{
              'filename': a.filename,
              if (a.mimeType != null) 'mime': a.mimeType,
              'bytes_b64': base64Encode(a.bytes),
            },
          )
          .toList(),
    };

    final jsonBytes = utf8.encode(jsonEncode(map));
    return Uint8List.fromList(jsonBytes);
  }

  DecryptedPayload decode(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid payload JSON');
    }

    final version = (decoded['v'] as num?)?.toInt() ?? 0;
    final content = (decoded['content'] as String?) ?? '';
    final replyToId = decoded['reply_to'] as String?;

    final attachmentsRaw = decoded['attachments'];
    final attachments = <DecryptedAttachment>[];
    if (attachmentsRaw is List) {
      for (final item in attachmentsRaw) {
        if (item is! Map) continue;
        final filename = item['filename'] as String?;
        final bytesB64 = item['bytes_b64'] as String?;
        if (filename == null || bytesB64 == null) continue;
        final mime = item['mime'] as String?;
        attachments.add(
          DecryptedAttachment(
            filename: filename,
            mimeType: mime,
            bytes: Uint8List.fromList(base64Decode(bytesB64)),
          ),
        );
      }
    }

    return DecryptedPayload(
      version: version,
      content: content,
      replyToId: replyToId,
      attachments: attachments,
    );
  }
}

