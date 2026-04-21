import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';
import 'package:erebusv3/classes/auth_provider.dart';
import 'package:erebusv3/classes/themes.dart';
import 'package:erebusv3/services/e2ee/message_crypto.dart';
import 'package:erebusv3/services/e2ee/models.dart';
import 'package:erebusv3/services/e2ee/payload_codec.dart';
import 'package:erebusv3/services/e2ee/pb_file_downloader.dart';
import 'package:erebusv3/services/e2ee/public_key_repository.dart';
import 'package:erebusv3/services/e2ee/secure_storage.dart';
import 'package:erebusv3/services/e2ee/signature_service.dart';
import 'package:cryptography/cryptography.dart';

class ChatScreen extends StatefulWidget {
  final RecordModel chat;

  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  File? _selectedAttachment;
  String? _selectedAttachmentName;

  Map<String, RecordModel> _messages = {};
  final Map<String, DecryptedMessageView> _decryptedMessages = {};
  List<RecordModel> _searchResults = [];
  int _currentSearchIndex = 0;

  bool _isLoading = true;
  bool _isInitialDecrypting = true;
  bool _hasCompletedInitialDecrypt = false;
  int _initialTotalMessages = 0;
  int _initialProcessedMessages = 0;
  int _initialDecryptedMessages = 0;
  bool _isSearching = false;
  String? _chatTitle;
  String? _highlightedMessageId;
  late final String _currentUserId;
  late final PocketBase _pb;

  late final PublicKeyRepository _publicKeyRepo;
  late final PbFileDownloader _pbDownloader;
  late final MessageCrypto _messageCrypto;
  final SignatureService _signatureService = SignatureService();
  final PayloadCodec _payloadCodec = PayloadCodec();
  final E2eeSecureStorage _e2eeStorage = E2eeSecureStorage();
  final Cipher _aead = Xchacha20.poly1305Aead();

  // Reply state
  String? _replyingToId;
  RecordModel? _replyingToMessage;

  // Message keys for scrolling to specific messages
  final Map<String, GlobalKey> _messageKeys = {};

  // Upload state tracking
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUserId = authProvider.currentUser!.id;
    _pb = authProvider.pb;
    _publicKeyRepo = PublicKeyRepository(_pb);
    _pbDownloader = PbFileDownloader(_pb);
    _messageCrypto = MessageCrypto(downloader: _pbDownloader);

    _chatTitle = _getChatTitle(widget.chat, _currentUserId);
    _fetchMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _pb.realtime.unsubscribe('messages');
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Data Logic (Using non-deprecated access) ---

  RecordModel? _getOtherMember(RecordModel chat, String currentUserId) {
    // FIX: Uses chat.get<List<RecordModel>>('expand.members')
    final expandedMembers = chat.get<List<RecordModel>>('expand.members');

    if (expandedMembers.isEmpty) return null;
    final otherMembers = expandedMembers
        .where((member) => member.id != currentUserId)
        .toList();
    return otherMembers.isEmpty ? null : otherMembers.first;
  }

  String _getChatTitle(RecordModel chat, String currentUserId) {
    if (chat.getStringValue('type', '') == 'group') {
      return chat.getStringValue('title', 'Group Chat');
    }
    final otherMember = _getOtherMember(chat, currentUserId);
    if (otherMember != null) {
      String title = otherMember.getStringValue('username', '');
      if (title.isNotEmpty) return title;
      title = otherMember.getStringValue('name', '');
      if (title.isNotEmpty) return title;
      return otherMember.id;
    }
    return 'Chat ID: ${widget.chat.id}';
  }

  String _getSenderDisplayName(RecordModel? senderRecord, bool isMe) {
    if (isMe) return 'You';
    if (senderRecord == null) return 'Unknown';
    final name = senderRecord.getStringValue('name', '');
    if (name.isNotEmpty) return name;
    final username = senderRecord.getStringValue('username', '');
    if (username.isNotEmpty) return username;
    return senderRecord.id;
  }

  // --- PocketBase Logic ---

  Future<void> _fetchMessages() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final showInitialProgress = !_hasCompletedInitialDecrypt;

    if (showInitialProgress && mounted) {
      setState(() {
        _isLoading = true;
        _isInitialDecrypting = true;
        _initialTotalMessages = 0;
        _initialProcessedMessages = 0;
        _initialDecryptedMessages = 0;
      });
    }

    try {
      final result = await authProvider.pb
          .collection('messages')
          .getFullList(
            filter: 'chat = "${widget.chat.id}"',
            expand: 'sender,reply_to,reply_to.sender',
            sort: 'created',
          );

      final newMessages = <String, RecordModel>{};
      final newDecrypted = <String, DecryptedMessageView>{};

      final kyberSecretRaw = await _e2eeStorage.readBase64(
        E2eeSecureStorage.kyberSecretKey(
          _currentUserId,
          namespace: authProvider.e2eeKeyNamespace,
        ),
      );
      final kyberSecret = kyberSecretRaw == null
          ? null
          : Uint8List.fromList(base64.decode(kyberSecretRaw));

      final scopedMessages = result.where((msg) {
        final recipientId = msg.getStringValue('recipient', '');
        return recipientId.isEmpty || recipientId == _currentUserId;
      }).toList();

      if (showInitialProgress && mounted) {
        setState(() {
          _initialTotalMessages = scopedMessages.length;
        });
      }

      for (final msg in scopedMessages) {
        int processedDelta = 0;
        int decryptedDelta = 0;

        newMessages[msg.id] = msg;

        final kemFilename = msg.getStringValue('kem_ciphertext', '');
        final saltFilename = msg.getStringValue('hkdf_salt', '');
        final nonceFilename = msg.getStringValue('xc20_nonce', '');
        final ciphertextFilename = msg.getStringValue('ciphertext', '');
        final authTagFilename = msg.getStringValue('auth_tag', '');
        final signatureFilename = msg.getStringValue('signature', '');

        final isEncrypted =
            kemFilename.isNotEmpty &&
            saltFilename.isNotEmpty &&
            nonceFilename.isNotEmpty &&
            ciphertextFilename.isNotEmpty &&
            authTagFilename.isNotEmpty &&
            signatureFilename.isNotEmpty;

        if (!isEncrypted) {
          processedDelta = 1;
          if (showInitialProgress && mounted) {
            setState(() {
              _initialProcessedMessages += processedDelta;
            });
          }
          continue;
        }
        if (kyberSecret == null) {
          // Can't decrypt without local secret keys; skip rendering encrypted items.
          processedDelta = 1;
          if (showInitialProgress && mounted) {
            setState(() {
              _initialProcessedMessages += processedDelta;
            });
          }
          continue;
        }

        try {
          final createdAt = DateTime.parse(
            msg.getStringValue('created', '1970-01-01T00:00:00Z'),
          );
          final timestampMs = createdAt.millisecondsSinceEpoch;
          final chatType = widget.chat.getStringValue('type', '');
          final aad = _messageCrypto.buildAad(
            chatType: chatType,
            chatId: widget.chat.id,
            timestampMs: timestampMs,
          );

          final payload = await _messageCrypto.decryptFromRecordFiles(
            recordId: msg.id,
            kemCiphertextFilename: kemFilename,
            hkdfSaltFilename: saltFilename,
            nonceFilename: nonceFilename,
            ciphertextFilename: ciphertextFilename,
            authTagFilename: authTagFilename,
            kyberSecretKey: kyberSecret,
            aad: aad,
          );

          final senderList = msg.get<List<RecordModel>>('expand.sender');
          final senderRecord = senderList.isNotEmpty ? senderList.first : null;
          final senderId = senderRecord?.id ?? msg.getStringValue('sender');

          final ciphertextBytes = await _pbDownloader.downloadFile(
            collection: 'messages',
            recordId: msg.id,
            filename: ciphertextFilename,
          );
          final authTagBytes = await _pbDownloader.downloadFile(
            collection: 'messages',
            recordId: msg.id,
            filename: authTagFilename,
          );
          final saltBytes = await _pbDownloader.downloadFile(
            collection: 'messages',
            recordId: msg.id,
            filename: saltFilename,
          );
          final nonceBytes = await _pbDownloader.downloadFile(
            collection: 'messages',
            recordId: msg.id,
            filename: nonceFilename,
          );
          final signatureBytes = await _pbDownloader.downloadFile(
            collection: 'messages',
            recordId: msg.id,
            filename: signatureFilename,
          );

          final senderKeys = await _publicKeyRepo.fetchUserPublicKeys(senderId);
          final signable = _signatureService.buildSignableBytes(
            version: 1,
            chatType: chatType,
            timestampMs: timestampMs,
            senderId: senderId,
            chatId: widget.chat.id,
            salt: saltBytes,
            nonce: nonceBytes,
            ciphertext: ciphertextBytes,
            authTag: authTagBytes,
          );

          final isVerified = _signatureService.verify(
            signableBytes: signable,
            signatureBytes: signatureBytes,
            dilithiumPublicKey: senderKeys.dilithiumPublicKey,
          );

          if (!isVerified) {
            // Per spec: never render failed verification/decrypt.
            continue;
          }

          newDecrypted[msg.id] = DecryptedMessageView(
            id: msg.id,
            senderId: senderId,
            created: createdAt,
            isVerified: isVerified,
            content: payload.content,
            replyToId: payload.replyToId,
            attachments: payload.attachments,
          );
          processedDelta = 1;
          decryptedDelta = 1;
        } catch (e) {
          // Skip any failures silently per spec.
          processedDelta = 1;
          continue;
        } finally {
          if (showInitialProgress && mounted) {
            setState(() {
              _initialProcessedMessages += processedDelta;
              _initialDecryptedMessages += decryptedDelta;
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _messages = newMessages;
          _decryptedMessages
            ..clear()
            ..addAll(newDecrypted);
          _isLoading = false;
          if (showInitialProgress) {
            _isInitialDecrypting = false;
            _hasCompletedInitialDecrypt = true;
          }
        });
      }
    } on ClientException catch (e) {
      debugPrint('Failed to load messages: ${e.response['message']}');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (showInitialProgress) {
            _isInitialDecrypting = false;
            _hasCompletedInitialDecrypt = true;
          }
        });
      }
      _showSnackBar(
        'Failed to load messages: ${e.response['message'] ?? 'Network error.'}',
        isError: true,
      );
    }
  }

  void _subscribeToMessages() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    authProvider.pb.realtime.subscribe('messages', (e) {
      if (e.data is Map) {
        final data = e.data as Map<String, dynamic>;

        if (data.containsKey('record') && data.containsKey('action')) {
          final recordJson = data['record'];
          final action = data['action'] as String?;

          if (recordJson is Map<String, dynamic> && action != null) {
            if (recordJson['chat'] == widget.chat.id) {
              debugPrint('Realtime update for current chat: $action');

              if (action == 'create' ||
                  action == 'update' ||
                  action == 'delete') {
                Future.delayed(
                  const Duration(milliseconds: 100),
                  _fetchMessages,
                );
              }
            }
          }
        }
      } else {
        debugPrint(
          'Realtime event received, but structure was not a Map. Refreshing all messages in chat.',
        );
        Future.delayed(const Duration(milliseconds: 100), _fetchMessages);
      }
    });
  }

  String? _validateFile(File file, String? fileName) {
    // Check file size (200MB limit)
    final fileSize = file.lengthSync();
    const maxSize = 200 * 1024 * 1024; // 200MB
    if (fileSize > maxSize) {
      return 'File too large: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB. Maximum allowed: 200MB';
    }

    return null; // File is valid
  }

  Future<String?> _getDownloadedFilePath(
    String attachmentUrl,
    String attachmentFilename,
  ) async {
    try {
      final erebusMediaDir = Directory(
        '/storage/emulated/0/Download/Erebus Media',
      );
      if (!erebusMediaDir.existsSync()) {
        return null;
      }

      // Check if file with same name already exists
      final files = erebusMediaDir.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith(attachmentFilename)) {
          debugPrint('File already exists: ${file.path}');
          return file.path;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking downloaded file path: $e');
      return null;
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty && _selectedAttachment == null) return;

    // Prevent multiple sends while uploading
    if (_isUploading) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Validate file before sending
    if (_selectedAttachment != null) {
      final validationError = _validateFile(
        _selectedAttachment!,
        _selectedAttachmentName,
      );
      if (validationError != null) {
        _showSnackBar(validationError, isError: true);
        return;
      }
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final chatType = widget.chat.getStringValue('type', '');
      final chatId = widget.chat.id;
      final messageGroupId = _newClientMessageId();

      // Resolve recipients from chat members.
      final recipientIds = _getRecipientIdsFromChat(widget.chat);
      if (!recipientIds.contains(_currentUserId)) {
        recipientIds.add(_currentUserId);
      }

      final attachments = <DecryptedAttachment>[];
      if (_selectedAttachment != null) {
        final filename =
            _selectedAttachmentName ??
            _selectedAttachment!.path.split(Platform.pathSeparator).last;
        final bytes = await _selectedAttachment!.readAsBytes();
        attachments.add(DecryptedAttachment(filename: filename, bytes: bytes));
      }

      final payloadBlob = _payloadCodec.encode(
        content: content,
        replyToId: _replyingToId,
        attachments: attachments,
      );

      final dilithiumSecretRaw = await _e2eeStorage.readBase64(
        E2eeSecureStorage.dilithiumSecretKey(
          _currentUserId,
          namespace: authProvider.e2eeKeyNamespace,
        ),
      );
      if (dilithiumSecretRaw == null) {
        throw Exception('Missing Dilithium secret key on device');
      }
      final dilithiumSecret = base64.decode(dilithiumSecretRaw);

      final progress = _showProgressDialog(
        'Sending encrypted message',
        'Encrypting and sending for ${recipientIds.length} recipient(s)...',
      );

      try {
        int done = 0;
        for (final recipientId in recipientIds) {
          // Create record first to obtain server-created timestamp for AAD.
          final body = <String, dynamic>{
            'chat': chatId,
            'sender': _currentUserId,
            'recipient': recipientId,
            'edited': false,
            'deleted': false,
            // For encrypted messages, we store a random client message id here
            // so we can later update/delete all recipients' copies without
            // storing plaintext.
            'content': messageGroupId,
            'attachments': <dynamic>[],
          };
          if (_replyingToId != null) body['reply_to'] = _replyingToId!;

          final createdRecord = await authProvider.pb
              .collection('messages')
              .create(body: body);

          final createdAt = DateTime.parse(
            createdRecord.getStringValue('created', ''),
          );
          final timestampMs = createdAt.millisecondsSinceEpoch;
          final aad = _messageCrypto.buildAad(
            chatType: chatType,
            chatId: chatId,
            timestampMs: timestampMs,
          );

          final salt = _messageCrypto.randomSalt32();
          final nonce = Uint8List.fromList(_aead.newNonce());

          final recipientKeys = await _publicKeyRepo.fetchUserPublicKeys(
            recipientId,
          );
          final encrypted = await _messageCrypto.encryptForRecipient(
            recipientKyberPublicKey: recipientKeys.kyberPublicKey,
            payloadBlob: payloadBlob,
            salt: salt,
            nonce: nonce,
            aad: aad,
          );

          final signable = _signatureService.buildSignableBytes(
            version: 1,
            chatType: chatType,
            timestampMs: timestampMs,
            senderId: _currentUserId,
            chatId: chatId,
            salt: encrypted.hkdfSalt,
            nonce: encrypted.xc20Nonce,
            ciphertext: encrypted.ciphertext,
            authTag: encrypted.authTag,
          );
          final signatureBytes = _signatureService.sign(
            signableBytes: signable,
            dilithiumSecretKey: Uint8List.fromList(dilithiumSecret),
          );

          await authProvider.pb
              .collection('messages')
              .update(
                createdRecord.id,
                files: [
                  http.MultipartFile.fromBytes(
                    'kem_ciphertext',
                    encrypted.kemCiphertext,
                    filename: 'kem_ct.bin',
                  ),
                  http.MultipartFile.fromBytes(
                    'hkdf_salt',
                    encrypted.hkdfSalt,
                    filename: 'salt.bin',
                  ),
                  http.MultipartFile.fromBytes(
                    'xc20_nonce',
                    encrypted.xc20Nonce,
                    filename: 'nonce.bin',
                  ),
                  http.MultipartFile.fromBytes(
                    'ciphertext',
                    encrypted.ciphertext,
                    filename: 'ciphertext.bin',
                  ),
                  http.MultipartFile.fromBytes(
                    'auth_tag',
                    encrypted.authTag,
                    filename: 'auth_tag.bin',
                  ),
                  http.MultipartFile.fromBytes(
                    'signature',
                    signatureBytes,
                    filename: 'sig.bin',
                  ),
                ],
              );

          done += 1;
          progress.value = done / recipientIds.length;
        }

        // Bump chat recency for Home ordering.
        await authProvider.pb
            .collection('chats')
            .update(
              chatId,
              body: {'last_message': DateTime.now().toUtc().toIso8601String()},
            );
      } finally {
        progress.value = 1.0;
        await _closeProgressDialog();
      }

      _messageController.clear();
      _clearAttachment();

      // Clear reply state after sending
      setState(() {
        _replyingToId = null;
        _replyingToMessage = null;
        _isUploading = false;
      });
    } on ClientException catch (e) {
      debugPrint('=== MESSAGE SEND ERROR ===');
      debugPrint('ClientException: ${e.toString()}');
      debugPrint('Response: ${e.response}');

      String errorMessage = 'Failed to send message';

      final response = e.response;
      debugPrint('Response status: ${response['status']}');
      debugPrint('Response message: ${response['message']}');
      debugPrint('Response data: ${response['data']}');

      if (response['message'] != null) {
        errorMessage += ': ${response['message']}';
      } else if (response['data'] != null && response['data'] is Map) {
        final data = response['data'] as Map;
        if (data.containsKey('attachments')) {
          errorMessage += ': File upload error - ${data['attachments']}';
        } else {
          errorMessage += ': Server validation error';
        }
      } else {
        errorMessage +=
            ': Server error (status: ${response['status'] ?? 'unknown'})';
      }

      // Add file information if uploading
      if (_selectedAttachment != null) {
        final fileName = _selectedAttachmentName ?? 'unknown';
        final fileExtension = fileName.split('.').last.toLowerCase();
        errorMessage += '\nFile: $fileName (.$fileExtension)';
      }

      _showSnackBar(errorMessage, isError: true);

      setState(() {
        _isUploading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('=== MESSAGE SEND ERROR (Generic) ===');
      debugPrint('Exception: $e');
      debugPrint('StackTrace: $stackTrace');

      String errorMessage = 'Failed to send message: $e';
      if (_selectedAttachment != null) {
        final fileName = _selectedAttachmentName ?? 'unknown';
        errorMessage += '\nFile: $fileName';
      }

      _showSnackBar(errorMessage, isError: true);

      setState(() {
        _isUploading = false;
      });
    }
  }

  String _newClientMessageId() {
    final bytes = Uint8List.fromList(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final b = StringBuffer();
    for (final v in bytes) {
      b.write(v.toRadixString(16).padLeft(2, '0'));
    }
    return b.toString();
  }

  List<String> _getRecipientIdsFromChat(RecordModel chat) {
    final fromExpand = chat.get<List<RecordModel>>('expand.members');
    if (fromExpand.isNotEmpty) {
      return fromExpand.map((m) => m.id).toSet().toList();
    }
    final raw = chat.getListValue('members');
    return raw.map((e) => e.toString()).toSet().toList();
  }

  bool _isEncryptedRecord(RecordModel message) {
    if (message.getStringValue('kem_ciphertext', '').isNotEmpty) return true;
    // During send/update transitions files may not be attached yet.
    // For E2EE records we store a logical message id in content and recipient is set.
    final recipient = message.getStringValue('recipient', '');
    if (recipient.isEmpty) return false;
    final content = message.getStringValue('content', '');
    return _looksLikeClientMessageId(content);
  }

  bool _looksLikeClientMessageId(String value) {
    final reg = RegExp(r'^[a-f0-9]{32}$');
    return reg.hasMatch(value);
  }

  DecryptedMessageView? _resolveDecryptedMessage(RecordModel message) {
    final direct = _decryptedMessages[message.id];
    if (direct != null) return direct;

    // Fallback for relation-expansion mismatch: reply_to may point at a
    // sibling recipient copy. Resolve via shared logical message id.
    final groupId = message.getStringValue('content', '');
    if (!_looksLikeClientMessageId(groupId)) return null;

    for (final entry in _messages.entries) {
      final rec = entry.value;
      if (rec.getStringValue('content', '') == groupId) {
        final dec = _decryptedMessages[entry.key];
        if (dec != null) return dec;
      }
    }
    return null;
  }

  String _displayContentForMessage(
    RecordModel message, {
    String fallback = '',
  }) {
    final decrypted = _resolveDecryptedMessage(message);
    if (decrypted != null) return decrypted.content;
    if (_isEncryptedRecord(message)) return 'Decrypting...';
    final content = message.getStringValue('content', fallback);
    return content;
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.single;
    if (pickedFile.path == null) return;

    setState(() {
      _selectedAttachment = File(pickedFile.path!);
      _selectedAttachmentName = pickedFile.name;
    });
  }

  void _clearAttachment() {
    setState(() {
      _selectedAttachment = null;
      _selectedAttachmentName = null;
    });
  }

  Future<void> _editMessage(RecordModel message) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isEncrypted =
        _decryptedMessages.containsKey(message.id) ||
        message.getStringValue('kem_ciphertext', '').isNotEmpty;
    final currentContent = isEncrypted
        ? (_decryptedMessages[message.id]?.content ?? '')
        : message.getStringValue('content', '');

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _EditMessageDialog(initialContent: currentContent),
    );

    if (result == null || result.isEmpty) {
      if (result != null) {
        _showSnackBar('Message cannot be empty', isError: true);
      }
      return;
    }

    try {
      if (isEncrypted) {
        final existing = _decryptedMessages[message.id];
        if (existing == null) {
          _showSnackBar(
            'Can’t edit yet: message not decrypted locally.',
            isError: true,
          );
          return;
        }

        await _rewriteEncryptedMessageForAllCopies(
          authProvider: authProvider,
          message: message,
          newContent: result,
          newAttachments: existing.attachments,
          edited: true,
          deleted: false,
        );
        _showSnackBar('Message updated');
      } else {
        await authProvider.pb
            .collection('messages')
            .update(message.id, body: {'content': result, 'edited': true});
        _showSnackBar('Message updated');
      }
    } on ClientException catch (e) {
      debugPrint('Message edit failed: ${e.response['message']}');
      _showSnackBar(
        'Failed to edit message: ${e.response['message'] ?? 'Network error.'}',
        isError: true,
      );
    }
  }

  Future<void> _deleteMessage(RecordModel message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text(
            'Are you sure you want to delete this message? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final isEncrypted =
          _decryptedMessages.containsKey(message.id) ||
          message.getStringValue('kem_ciphertext', '').isNotEmpty;

      if (isEncrypted) {
        await _rewriteEncryptedMessageForAllCopies(
          authProvider: authProvider,
          message: message,
          newContent: 'This message was deleted.',
          newAttachments: const <DecryptedAttachment>[],
          edited: false,
          deleted: true,
        );
        _showSnackBar('Message deleted');
      } else {
        await authProvider.pb
            .collection('messages')
            .update(
              message.id,
              body: {
                'deleted': true,
                'attachments': [],
                'content': 'This message was deleted.',
              },
            );
        _showSnackBar('Message deleted');
      }
    } on ClientException catch (e) {
      debugPrint('Message deletion failed: ${e.response['message']}');
      _showSnackBar(
        'Failed to delete message: ${e.response['message'] ?? 'Network error.'}',
        isError: true,
      );
    }
  }

  Future<void> _rewriteEncryptedMessageForAllCopies({
    required AuthProvider authProvider,
    required RecordModel message,
    required String newContent,
    required List<DecryptedAttachment> newAttachments,
    required bool edited,
    required bool deleted,
  }) async {
    // For encrypted messages, `content` is our client-side logical id.
    final messageGroupId = message.getStringValue('content', '');
    if (messageGroupId.isEmpty) {
      // Fall back to rewriting only this record.
      await _rewriteEncryptedMessage(
        authProvider: authProvider,
        message: message,
        newContent: newContent,
        newAttachments: newAttachments,
        edited: edited,
        deleted: deleted,
      );
      return;
    }

    final chatId = widget.chat.id;
    final senderId = message.getStringValue('sender', _currentUserId);

    final records = await authProvider.pb
        .collection('messages')
        .getFullList(
          filter:
              'chat = "$chatId" && sender = "$senderId" && content = "$messageGroupId"',
          sort: 'created',
        );

    for (final r in records) {
      await _rewriteEncryptedMessage(
        authProvider: authProvider,
        message: r,
        newContent: newContent,
        newAttachments: newAttachments,
        edited: edited,
        deleted: deleted,
      );
    }
  }

  Future<void> _rewriteEncryptedMessage({
    required AuthProvider authProvider,
    required RecordModel message,
    required String newContent,
    required List<DecryptedAttachment> newAttachments,
    required bool edited,
    required bool deleted,
  }) async {
    final recipientId = message.getStringValue('recipient', '');
    if (recipientId.isEmpty) {
      throw Exception('Encrypted message missing recipient id');
    }

    final dilithiumSecretRaw = await _e2eeStorage.readBase64(
      E2eeSecureStorage.dilithiumSecretKey(
        _currentUserId,
        namespace: authProvider.e2eeKeyNamespace,
      ),
    );
    if (dilithiumSecretRaw == null) {
      throw Exception('Missing Dilithium secret key on device');
    }
    final dilithiumSecret = Uint8List.fromList(
      base64.decode(dilithiumSecretRaw),
    );

    final createdAt = DateTime.parse(
      message.getStringValue('created', '1970-01-01T00:00:00Z'),
    );
    final timestampMs = createdAt.millisecondsSinceEpoch;
    final chatType = widget.chat.getStringValue('type', '');
    final aad = _messageCrypto.buildAad(
      chatType: chatType,
      chatId: widget.chat.id,
      timestampMs: timestampMs,
    );

    final payloadBlob = _payloadCodec.encode(
      content: newContent,
      replyToId: message.getStringValue('reply_to', '').isEmpty
          ? null
          : message.getStringValue('reply_to', ''),
      attachments: newAttachments,
    );

    final recipientKeys = await _publicKeyRepo.fetchUserPublicKeys(recipientId);
    final salt = _messageCrypto.randomSalt32();
    final nonce = Uint8List.fromList(_aead.newNonce());
    final encrypted = await _messageCrypto.encryptForRecipient(
      recipientKyberPublicKey: recipientKeys.kyberPublicKey,
      payloadBlob: payloadBlob,
      salt: salt,
      nonce: nonce,
      aad: aad,
    );

    final signable = _signatureService.buildSignableBytes(
      version: 1,
      chatType: chatType,
      timestampMs: timestampMs,
      senderId: _currentUserId,
      chatId: widget.chat.id,
      salt: encrypted.hkdfSalt,
      nonce: encrypted.xc20Nonce,
      ciphertext: encrypted.ciphertext,
      authTag: encrypted.authTag,
    );
    final signatureBytes = _signatureService.sign(
      signableBytes: signable,
      dilithiumSecretKey: dilithiumSecret,
    );

    await authProvider.pb
        .collection('messages')
        .update(
          message.id,
          body: {
            'edited': edited,
            'deleted': deleted,
            // Keep the message group id intact for future rewrites.
            'content': message.getStringValue('content', ''),
            'attachments': <dynamic>[],
          },
          files: [
            http.MultipartFile.fromBytes(
              'kem_ciphertext',
              encrypted.kemCiphertext,
              filename: 'kem_ct.bin',
            ),
            http.MultipartFile.fromBytes(
              'hkdf_salt',
              encrypted.hkdfSalt,
              filename: 'salt.bin',
            ),
            http.MultipartFile.fromBytes(
              'xc20_nonce',
              encrypted.xc20Nonce,
              filename: 'nonce.bin',
            ),
            http.MultipartFile.fromBytes(
              'ciphertext',
              encrypted.ciphertext,
              filename: 'ciphertext.bin',
            ),
            http.MultipartFile.fromBytes(
              'auth_tag',
              encrypted.authTag,
              filename: 'auth_tag.bin',
            ),
            http.MultipartFile.fromBytes(
              'signature',
              signatureBytes,
              filename: 'sig.bin',
            ),
          ],
        );
  }

  // --- Search Logic ---
  Future<void> _searchMessages(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _highlightedMessageId = null;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final q = query.toLowerCase();
      final matches =
          _messages.values.where((m) {
            final decrypted = _decryptedMessages[m.id];
            final text = (decrypted?.content ?? m.getStringValue('content', ''))
                .toLowerCase();
            return text.contains(q);
          }).toList()..sort(
            (a, b) => b
                .getStringValue('created', '')
                .compareTo(a.getStringValue('created', '')),
          );

      setState(() {
        _searchResults = matches.take(50).toList();
        _currentSearchIndex = 0;
        if (_searchResults.isNotEmpty) {
          _highlightedMessageId = _searchResults.first.id;
          _scrollToMessage(_searchResults.first.id);
        }
      });
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _scrollToMessage(String messageId) {
    // Use GlobalKey to scroll to the exact message
    final messageKey = _messageKeys[messageId];

    if (messageKey == null || messageKey.currentContext == null) {
      // Fallback: estimate scroll position if key not found
      final sortedMessages = _messages.values.toList()
        ..sort(
          (a, b) => b
              .getStringValue('created', '')
              .compareTo(a.getStringValue('created', '')),
        );

      final messageIndex = sortedMessages.indexWhere(
        (msg) => msg.id == messageId,
      );

      if (messageIndex == -1) return;

      final estimatedHeight = messageIndex * 120.0;

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            estimatedHeight,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
      return;
    }

    // Scroll to the message using its GlobalKey
    Future.delayed(const Duration(milliseconds: 100), () {
      Scrollable.ensureVisible(
        messageKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5, // Center the message in view
      );
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _highlightedMessageId = null;
      _currentSearchIndex = 0;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final appTheme = context.read<ThemeNotifier>().currentTheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: appTheme.backgroundText),
        ),
        backgroundColor: isError ? Colors.red : appTheme.accent,
      ),
    );
  }

  ValueNotifier<double> _showProgressDialog(String title, String subtitle) {
    final progressNotifier = ValueNotifier<double>(0.0);

    if (!mounted) return progressNotifier;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final appTheme = context.read<ThemeNotifier>().currentTheme;
        return AlertDialog(
          backgroundColor: appTheme.background,
          title: Text(title, style: TextStyle(color: appTheme.backgroundText)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(subtitle, style: TextStyle(color: appTheme.backgroundText)),
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, progress, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: progress > 0 && progress <= 1 ? progress : null,
                        backgroundColor: appTheme.backgroundText.withAlpha(
                          (0.2 * 255).round(),
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          appTheme.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        progress > 0
                            ? '${(progress * 100).round()}%'
                            : 'Starting...',
                        style: TextStyle(color: appTheme.backgroundText),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    return progressNotifier;
  }

  Future<void> _closeProgressDialog() async {
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<ThemeNotifier>().currentTheme;

    final sortedMessages = _messages.values.toList()
      ..sort(
        (a, b) => b
            .getStringValue('created', '')
            .compareTo(a.getStringValue('created', '')),
      );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _chatTitle ?? 'Loading Chat...',
          style: TextStyle(color: appTheme.backgroundText),
        ),
        backgroundColor: appTheme.background,
        iconTheme: IconThemeData(color: appTheme.backgroundText),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: appTheme.backgroundText),
            onPressed: () => _showSearchBar(appTheme),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_isSearching) _buildSearchBar(appTheme),
          if (_searchResults.isNotEmpty) _buildSearchResults(appTheme),
          Expanded(
            child: _isLoading && _isInitialDecrypting
                ? _buildInitialDecryptProgress(appTheme)
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchMessages,
                    child: _messages.isEmpty
                        ? CustomScrollView(
                            slivers: [
                              SliverFillRemaining(
                                child: const Center(
                                  child: Text('No messages yet. Say hello!'),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.only(top: 10.0),
                            itemCount: sortedMessages.length,
                            itemBuilder: (context, index) {
                              final message = sortedMessages[index];
                              final isHighlighted =
                                  message.id == _highlightedMessageId;
                              return _buildMessageBubble(
                                message,
                                appTheme,
                                isHighlighted: isHighlighted,
                              );
                            },
                          ),
                  ),
          ),
          if (_replyingToMessage != null) _buildReplyPreview(appTheme),
          _buildMessageComposer(appTheme),
        ],
      ),
    );
  }

  // --- UI Helpers ---
  Widget _buildInitialDecryptProgress(AppThemeData appTheme) {
    final total = _initialTotalMessages;
    final processed = _initialProcessedMessages.clamp(0, total == 0 ? 0 : total);
    final ratio = total == 0 ? null : processed / total;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Decrypting messages...',
              style: TextStyle(
                color: appTheme.backgroundText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: ratio,
              backgroundColor: appTheme.backgroundText.withAlpha((0.2 * 255).round()),
              valueColor: AlwaysStoppedAnimation<Color>(appTheme.accent),
            ),
            const SizedBox(height: 12),
            Text(
              '$processed / $total processed',
              style: TextStyle(color: appTheme.backgroundText),
            ),
            const SizedBox(height: 4),
            Text(
              '$_initialDecryptedMessages decrypted',
              style: TextStyle(color: appTheme.backgroundText.withAlpha(200)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchBar(AppThemeData appTheme) {
    setState(() => _isSearching = true);
    _searchController.clear();
    _searchResults = [];
    _highlightedMessageId = null;
  }

  Widget _buildSearchBar(AppThemeData appTheme) {
    return Container(
      color: appTheme.background,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search messages...',
                hintStyle: TextStyle(
                  color: appTheme.backgroundText.withAlpha(128),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                prefixIcon: Icon(Icons.search, color: appTheme.accent),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: appTheme.accent),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _highlightedMessageId = null;
                          });
                        },
                      )
                    : null,
              ),
              style: TextStyle(color: appTheme.backgroundText),
              onChanged: (query) {
                _searchMessages(query);
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close, color: appTheme.accent),
            onPressed: () {
              _clearSearch();
              setState(() => _isSearching = false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(AppThemeData appTheme) {
    if (_searchResults.isEmpty) {
      return Container(
        color: appTheme.background,
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'No results found',
          style: TextStyle(color: appTheme.backgroundText),
        ),
      );
    }

    return Container(
      color: appTheme.background,
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_currentSearchIndex + 1}/${_searchResults.length} result${_searchResults.length == 1 ? '' : 's'}',
              style: TextStyle(color: appTheme.backgroundText),
            ),
          ),
          IconButton(
            icon: Icon(Icons.keyboard_arrow_up, color: appTheme.accent),
            tooltip: 'Previous result',
            onPressed: _searchResults.isEmpty
                ? null
                : () {
                    setState(() {
                      _currentSearchIndex =
                          (_currentSearchIndex - 1 + _searchResults.length) %
                          _searchResults.length;
                      _highlightedMessageId =
                          _searchResults[_currentSearchIndex].id;
                    });
                    _scrollToMessage(_highlightedMessageId!);
                  },
          ),
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down, color: appTheme.accent),
            tooltip: 'Next result',
            onPressed: _searchResults.isEmpty
                ? null
                : () {
                    setState(() {
                      _currentSearchIndex =
                          (_currentSearchIndex + 1) % _searchResults.length;
                      _highlightedMessageId =
                          _searchResults[_currentSearchIndex].id;
                    });
                    _scrollToMessage(_highlightedMessageId!);
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    RecordModel message,
    AppThemeData appTheme, {
    bool isHighlighted = false,
  }) {
    final isUploadingMessage = message.id == 'uploading';

    final senderList = message.get<List<RecordModel>>('expand.sender');
    final senderRecord = senderList.isNotEmpty ? senderList.first : null;
    final senderId = senderRecord?.id ?? message.getStringValue('sender');
    final isMe = senderId == _currentUserId;
    final senderName = _getSenderDisplayName(senderRecord, isMe);

    final decrypted = _resolveDecryptedMessage(message);
    final content = _displayContentForMessage(message, fallback: 'Loading...');
    final timestamp = isUploadingMessage
        ? DateTime.now()
        : DateTime.parse(
            message.getStringValue('created', '1970-01-01T00:00:00Z'),
          );
    final isDeleted = message.getBoolValue('deleted', false);
    final isEdited = message.getBoolValue('edited', false);

    final decryptedAttachments =
        decrypted?.attachments ?? const <DecryptedAttachment>[];
    final attachmentValue = message.get('attachments');
    final legacyAttachmentFiles = attachmentValue is List
        ? attachmentValue.cast<dynamic>()
        : <dynamic>[];
    final legacyAttachmentName = legacyAttachmentFiles.isNotEmpty
        ? legacyAttachmentFiles.first.toString()
        : null;

    // Try to get parent message from expanded reply_to first, then fallback to _messages
    RecordModel? parentMessage;
    final expandedReplyTo = message.get<List<RecordModel>>('expand.reply_to');
    if (expandedReplyTo.isNotEmpty) {
      parentMessage = expandedReplyTo.first;
    } else {
      final replyToId = message.getStringValue('reply_to', '');
      if (replyToId.isNotEmpty) {
        parentMessage = _messages[replyToId];
      }
    }

    // --- CUSTOM THEME COLORS FOR BUBBLES ---
    final bubbleColor = isMe ? appTheme.sentBubble : appTheme.receivedBubble;
    final contentColor = isMe ? appTheme.sentText : appTheme.receivedText;
    final timestampColor = contentColor.withAlpha((0.7 * 255).round());
    // ------------------------------------

    final messageBubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        // --- Use the theme-aware bubbleColor ---
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(15),
          topRight: const Radius.circular(15),
          bottomLeft: isMe
              ? const Radius.circular(15)
              : const Radius.circular(5),
          bottomRight: isMe
              ? const Radius.circular(5)
              : const Radius.circular(15),
        ),
        border: isHighlighted
            ? Border.all(color: appTheme.accent, width: 2.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parentMessage != null && !isDeleted)
            _buildQuotedMessage(parentMessage, appTheme, contentColor),

          if (!isDeleted && decryptedAttachments.isNotEmpty)
            ...decryptedAttachments.map(
              (a) => _buildDecryptedAttachmentPreview(a, appTheme),
            ),
          if (!isDeleted &&
              decryptedAttachments.isEmpty &&
              legacyAttachmentName != null)
            _buildAttachmentPreview(
              legacyAttachmentName,
              isUploadingMessage
                  ? ''
                  : _pb.files.getURL(message, legacyAttachmentName).toString(),
              appTheme,
              messageId: message.id,
            ),

          if (widget.chat.getStringValue('type', '') == 'group')
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                senderName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: appTheme.accent,
                ),
              ),
            ),

          Text(
            isDeleted ? 'This message was deleted' : content,
            style: TextStyle(
              // --- Use the theme-aware contentColor ---
              color: isDeleted ? contentColor : contentColor,
              fontSize: 15.0,
              fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
            ),
          ),

          const SizedBox(height: 4),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 12, color: timestampColor),
              ),
              if (decrypted != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.verified, size: 14, color: appTheme.accent),
              ],
              if (isEdited && !isDeleted) ...[
                const SizedBox(width: 6),
                Text(
                  'Edited',
                  style: TextStyle(fontSize: 12, color: timestampColor),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    // Build message row with optional swipe action
    final messageLabel = isDeleted
        ? 'Deleted message from $senderName'
        : '$senderName: $content';

    // Create or reuse GlobalKey for this message
    _messageKeys.putIfAbsent(message.id, () => GlobalKey());
    final messageKey = _messageKeys[message.id]!;

    final messageWidget = Semantics(
      label: messageLabel,
      enabled: true,
      button: isMe && !isDeleted,
      child: isMe
          ? Align(
              alignment: Alignment.centerRight,
              child: _buildSwipeableMessage(
                messageBubble,
                message,
                appTheme,
                isMe,
                isDeleted,
              ),
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: _buildSwipeableMessage(
                messageBubble,
                message,
                appTheme,
                isMe,
                isDeleted,
              ),
            ),
    );

    return KeyedSubtree(key: messageKey, child: messageWidget);
  }

  Widget _buildSwipeableMessage(
    Widget messageBubble,
    RecordModel message,
    AppThemeData appTheme,
    bool isMe,
    bool isDeleted,
  ) {
    return _SwipeableMessageWidget(
      messageBubble: messageBubble,
      message: message,
      appTheme: appTheme,
      isMe: isMe,
      isDeleted: isDeleted,
      onReply: !isDeleted ? _setReplyingTo : null,
      onLongPress: isMe && !isDeleted
          ? () => _showMessageMenu(context, message, appTheme)
          : null,
    );
  }

  void _showMessageMenu(
    BuildContext context,
    RecordModel message,
    AppThemeData appTheme,
  ) {
    final isEncrypted =
        _decryptedMessages.containsKey(message.id) ||
        message.getStringValue('kem_ciphertext', '').isNotEmpty;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: appTheme.background,
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.reply, color: appTheme.accent),
              title: Text(
                'Reply',
                style: TextStyle(color: appTheme.backgroundText),
              ),
              onTap: () {
                Navigator.pop(context);
                _setReplyingTo(message);
              },
            ),
            if (!isEncrypted)
              ListTile(
                leading: Icon(Icons.edit, color: appTheme.accent),
                title: Text(
                  'Edit',
                  style: TextStyle(color: appTheme.backgroundText),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setReplyingTo(RecordModel message) {
    setState(() {
      _replyingToId = message.id;
      _replyingToMessage = message;
    });
  }

  void _clearReply() {
    setState(() {
      _replyingToId = null;
      _replyingToMessage = null;
    });
  }

  Widget _buildReplyPreview(AppThemeData appTheme) {
    final senderList = _replyingToMessage!.get<List<RecordModel>>(
      'expand.sender',
    );
    final senderRecord = senderList.isNotEmpty ? senderList.first : null;
    final replySenderId = _replyingToMessage!.getStringValue('sender');
    final isMe = replySenderId == _currentUserId;
    final senderName = _getSenderDisplayName(senderRecord, isMe);
    final content = _displayContentForMessage(_replyingToMessage!);
    final truncatedContent = content.length > 50
        ? '${content.substring(0, 50)}...'
        : content;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: appTheme.background,
        border: Border(left: BorderSide(color: appTheme.accent, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $senderName',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: appTheme.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  truncatedContent,
                  style: TextStyle(
                    fontSize: 13,
                    color: appTheme.backgroundText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: appTheme.accent, size: 18),
            onPressed: _clearReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotedMessage(
    RecordModel parentMessage,
    AppThemeData appTheme,
    Color contentColor,
  ) {
    final senderList = parentMessage.get<List<RecordModel>>('expand.sender');
    final senderRecord = senderList.isNotEmpty ? senderList.first : null;
    final parentSenderId = parentMessage.getStringValue('sender');
    final isMe = parentSenderId == _currentUserId;
    final senderName = _getSenderDisplayName(senderRecord, isMe);
    final content = _displayContentForMessage(parentMessage);
    final truncatedContent = content.length > 40
        ? '${content.substring(0, 40)}...'
        : content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: contentColor.withAlpha((0.15 * 255).round()),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                senderName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: contentColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                truncatedContent,
                style: TextStyle(fontSize: 12, color: contentColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildAttachmentPreview(
    String attachmentName,
    String attachmentUrl,
    AppThemeData appTheme, {
    String? messageId,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
      decoration: BoxDecoration(
        color: appTheme.backgroundText.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_file, size: 18, color: appTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attachment',
                  style: TextStyle(
                    color: appTheme.backgroundText,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  attachmentName,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: appTheme.backgroundText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          FutureBuilder<String?>(
            future: _getDownloadedFilePath(attachmentUrl, attachmentName),
            builder: (context, snapshot) {
              final fileExists = snapshot.data != null;

              if (fileExists) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Downloaded',
                      style: TextStyle(
                        color: appTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }

              return TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: appTheme.accent,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Download'),
                onPressed: () =>
                    _openAttachment(attachmentUrl, attachmentName, messageId),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Calculate SHA256 hash of file bytes
  String _calculateFileHash(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Check if a file with the same hash already exists in Erebus Media directory
  Future<String?> _findExistingFileByHash(String fileHash) async {
    final downloadsDir = '/storage/emulated/0/Download';
    final erebusMediaDir = Directory('$downloadsDir/Erebus Media');

    if (!erebusMediaDir.existsSync()) {
      return null;
    }

    try {
      final files = erebusMediaDir.listSync();
      for (final entity in files) {
        if (entity is File) {
          try {
            final existingBytes = await entity.readAsBytes();
            final existingHash = _calculateFileHash(existingBytes);
            if (existingHash == fileHash) {
              debugPrint(
                'Found existing file with matching hash: ${entity.path}',
              );
              return entity.path;
            }
          } catch (e) {
            debugPrint('Error reading file ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning directory: $e');
    }

    return null;
  }

  Future<void> _openAttachment(
    String attachmentUrl,
    String attachmentFilename, [
    String? messageId,
  ]) async {
    final downloadProgress = _showProgressDialog(
      'Downloading attachment',
      'Please wait while the file is downloaded.',
    );

    try {
      debugPrint('=== ATTACHMENT DOWNLOAD START ===');
      debugPrint('Attachment URL: $attachmentUrl');
      debugPrint('Attachment Filename: $attachmentFilename');

      final request = http.Request('GET', Uri.parse(attachmentUrl));
      final streamedResponse = await request.send();

      debugPrint('Response Status Code: ${streamedResponse.statusCode}');
      debugPrint('Response Content-Length: ${streamedResponse.contentLength}');

      if (streamedResponse.statusCode == 200) {
        final totalBytes = streamedResponse.contentLength ?? 0;
        final bytes = <int>[];
        int receivedBytes = 0;

        await for (final chunk in streamedResponse.stream) {
          bytes.addAll(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            downloadProgress.value = (receivedBytes / totalBytes).clamp(
              0.0,
              1.0,
            );
          }
        }

        if (totalBytes > 0) {
          downloadProgress.value = 1.0;
        }

        debugPrint('Download successful. Calculating file hash...');

        // Calculate SHA256 hash for deduplication
        final fileHash = _calculateFileHash(bytes);
        debugPrint('File hash (SHA256): $fileHash');

        // Check if file with same hash already exists
        final existingFile = await _findExistingFileByHash(fileHash);
        if (existingFile != null) {
          debugPrint('File already downloaded with identical content');
          _showSnackBar(
            'File already downloaded: ${File(existingFile).uri.pathSegments.last}',
            isError: false,
          );

          // Force UI update to hide download button
          if (mounted) {
            setState(() {});
          }

          debugPrint('=== ATTACHMENT DOWNLOAD SKIPPED (DUPLICATE) ===');
          return;
        }

        debugPrint('No existing file with matching hash. Saving new file...');

        // Use public Downloads directory on Android
        final downloadsDir = '/storage/emulated/0/Download';
        debugPrint('Downloads directory: $downloadsDir');

        // Create Erebus Media folder inside Downloads
        final erebusMediaDir = Directory('$downloadsDir/Erebus Media');
        if (!erebusMediaDir.existsSync()) {
          debugPrint('Creating Erebus Media directory...');
          erebusMediaDir.createSync(recursive: true);
          debugPrint('Directory created: ${erebusMediaDir.path}');
        } else {
          debugPrint(
            'Erebus Media directory already exists: ${erebusMediaDir.path}',
          );
        }

        final chatName = _chatTitle ?? 'Chat';
        final finalFilename = '$chatName - $attachmentFilename';
        final filePath = '${erebusMediaDir.path}/$finalFilename';

        debugPrint('Saving file as: $finalFilename');
        debugPrint('Full path: $filePath');

        final file = File(filePath);
        await file.writeAsBytes(bytes);

        debugPrint('File saved successfully!');
        debugPrint('File exists: ${file.existsSync()}');
        debugPrint('File size: ${file.lengthSync()} bytes');

        _showSnackBar(
          'Saved to Downloads/Erebus Media: $finalFilename',
          isError: false,
        );

        // Force UI update to hide download button
        if (mounted) {
          setState(() {});
        }

        debugPrint('=== ATTACHMENT DOWNLOAD SUCCESS ===');
      } else {
        debugPrint(
          'Download failed with status code: ${streamedResponse.statusCode}',
        );

        _showSnackBar(
          'Failed to download attachment: ${streamedResponse.statusCode}',
          isError: true,
        );
        debugPrint('=== ATTACHMENT DOWNLOAD FAILED ===');
      }
    } catch (e, stackTrace) {
      debugPrint('=== ATTACHMENT DOWNLOAD ERROR ===');
      debugPrint('Exception: $e');
      debugPrint('StackTrace: $stackTrace');

      _showSnackBar(
        'Error downloading attachment: ${e.toString()}',
        isError: true,
      );
    } finally {
      downloadProgress.value = 1.0;
      await _closeProgressDialog();
    }
  }

  Widget _buildDecryptedAttachmentPreview(
    DecryptedAttachment attachment,
    AppThemeData appTheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
      decoration: BoxDecoration(
        color: appTheme.backgroundText.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock, size: 18, color: appTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Encrypted attachment',
                  style: TextStyle(
                    color: appTheme.backgroundText,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  attachment.filename,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: appTheme.backgroundText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: appTheme.accent,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Save'),
            onPressed: () => _saveDecryptedAttachment(
              bytes: attachment.bytes,
              attachmentFilename: attachment.filename,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDecryptedAttachment({
    required Uint8List bytes,
    required String attachmentFilename,
  }) async {
    final downloadProgress = _showProgressDialog(
      'Saving attachment',
      'Please wait while the file is saved.',
    );

    try {
      downloadProgress.value = 0.3;
      final fileHash = _calculateFileHash(bytes);
      final existingFile = await _findExistingFileByHash(fileHash);
      if (existingFile != null) {
        _showSnackBar(
          'File already downloaded: ${File(existingFile).uri.pathSegments.last}',
          isError: false,
        );
        return;
      }

      downloadProgress.value = 0.7;
      final downloadsDir = '/storage/emulated/0/Download';
      final erebusMediaDir = Directory('$downloadsDir/Erebus Media');
      if (!erebusMediaDir.existsSync()) {
        erebusMediaDir.createSync(recursive: true);
      }

      final chatName = _chatTitle ?? 'Chat';
      final finalFilename = '$chatName - $attachmentFilename';
      final filePath = '${erebusMediaDir.path}/$finalFilename';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      _showSnackBar(
        'Saved to Downloads/Erebus Media: $finalFilename',
        isError: false,
      );
    } catch (e) {
      _showSnackBar('Error saving attachment: ${e.toString()}', isError: true);
    } finally {
      downloadProgress.value = 1.0;
      await _closeProgressDialog();
    }
  }

  Widget _buildMessageComposer(AppThemeData appTheme) {
    final canSend =
        (_messageController.text.trim().isNotEmpty ||
        _selectedAttachment != null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: appTheme.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedAttachmentName != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 10.0,
              ),
              decoration: BoxDecoration(
                color: appTheme.backgroundText.withAlpha((0.08 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_file, color: appTheme.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedAttachmentName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: appTheme.backgroundText),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: appTheme.backgroundText),
                    onPressed: _clearAttachment,
                    tooltip: 'Remove attachment',
                  ),
                ],
              ),
            ),
          Row(
            children: <Widget>[
              Semantics(
                label: 'Attachment button',
                button: true,
                enabled: true,
                child: IconButton(
                  icon: Icon(Icons.attachment, color: appTheme.accent),
                  onPressed: _pickAttachment,
                ),
              ),

              Expanded(
                child: Semantics(
                  label: 'Message input field',
                  textField: true,
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (text) => setState(() {}),
                    style: TextStyle(color: appTheme.backgroundText),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Send a message...',
                      hintStyle: TextStyle(
                        color: appTheme.backgroundText.withAlpha(128),
                      ),
                    ),
                  ),
                ),
              ),

              Semantics(
                label: canSend
                    ? 'Send message button'
                    : 'Send message button, disabled',
                button: true,
                enabled: canSend,
                child: IconButton(
                  icon: Icon(
                    Icons.send,
                    color: canSend
                        ? appTheme.accent
                        : appTheme.backgroundText.withAlpha(
                            (0.3 * 255).round(),
                          ),
                  ),
                  onPressed: canSend ? _sendMessage : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditMessageDialog extends StatefulWidget {
  final String initialContent;

  const _EditMessageDialog({required this.initialContent});

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Message'),
      content: TextField(
        controller: _controller,
        maxLines: null,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Edit your message...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SwipeableMessageWidget extends StatefulWidget {
  final Widget messageBubble;
  final RecordModel message;
  final AppThemeData appTheme;
  final bool isMe;
  final bool isDeleted;
  final Function(RecordModel)? onReply;
  final VoidCallback? onLongPress;

  const _SwipeableMessageWidget({
    required this.messageBubble,
    required this.message,
    required this.appTheme,
    required this.isMe,
    required this.isDeleted,
    this.onReply,
    this.onLongPress,
  });

  @override
  State<_SwipeableMessageWidget> createState() =>
      _SwipeableMessageWidgetState();
}

class _SwipeableMessageWidgetState extends State<_SwipeableMessageWidget> {
  double _swipeOffset = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: widget.onReply != null
          ? (details) {
              setState(() {
                _swipeOffset += details.delta.dx;
                if (widget.isMe) {
                  // Sent messages: swipe right to left (negative)
                  _swipeOffset = _swipeOffset.clamp(-60, 0).toDouble();
                } else {
                  // Received messages: swipe left to right (positive)
                  _swipeOffset = _swipeOffset.clamp(0, 60).toDouble();
                }
              });
            }
          : null,
      onHorizontalDragEnd: widget.onReply != null
          ? (details) {
              // Check swipe direction based on message position
              bool shouldReply = false;
              if (widget.isMe) {
                // Sent messages: swipe left with velocity or > 50px
                shouldReply =
                    details.velocity.pixelsPerSecond.dx < -500 ||
                    _swipeOffset < -50;
              } else {
                // Received messages: swipe right with velocity or > 50px
                shouldReply =
                    details.velocity.pixelsPerSecond.dx > 500 ||
                    _swipeOffset > 50;
              }

              if (shouldReply && widget.onReply != null) {
                widget.onReply!(widget.message);
              }
              setState(() {
                _swipeOffset = 0;
              });
            }
          : null,
      onHorizontalDragCancel: widget.onReply != null
          ? () {
              setState(() {
                _swipeOffset = 0;
              });
            }
          : null,
      child: Transform.translate(
        offset: Offset(_swipeOffset, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply icon on left (for received messages)
            if (!widget.isMe && _swipeOffset > 20)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  Icons.reply,
                  color: widget.appTheme.accent,
                  size: 20,
                ),
              ),
            // Message bubble with long-press for own messages
            widget.onLongPress != null
                ? GestureDetector(
                    onLongPress: widget.onLongPress,
                    child: widget.messageBubble,
                  )
                : widget.messageBubble,
            // Reply icon on right (for sent messages)
            if (widget.isMe && _swipeOffset < -20)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Icon(
                  Icons.reply,
                  color: widget.appTheme.accent,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
