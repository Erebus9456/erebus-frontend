# E2EE Cryptography

Erebus implements a **hybrid post-quantum end-to-end encryption** scheme. The server stores only encrypted artifacts and public keys; all secret key material remains on the client device.

## Algorithm Summary

| Purpose | Algorithm | Library |
|---------|-----------|---------|
| Key encapsulation (KEM) | ML-KEM-512 (Kyber) | `oqs` |
| Digital signatures | Dilithium2 | `oqs` |
| Key derivation | HKDF-SHA256 | `cryptography` |
| Authenticated encryption | XChaCha20-Poly1305 (AEAD) | `cryptography` |

## Identity Keys

Each user has two keypairs, generated on-device by `KeyManager`:

### Generation (`key_manager.dart`)

Triggered by `AuthProvider.ensureE2eeKeysReady()` after login/register.

1. Check local secure storage for existing Kyber + Dilithium secret keys
2. Check PocketBase user record for uploaded public key file fields
3. If all present → return early (keys already established)
4. Otherwise:
   - Generate ML-KEM-512 keypair via `oqs.KEM.create('ML-KEM-512')`
   - Generate Dilithium2 keypair via `oqs.Signature.create('Dilithium2')`
   - Store secret keys in `flutter_secure_storage` (base64-encoded)
   - Upload public keys as file fields on the user record
   - Set `key_version: 1` and `key_rotated_at` timestamp

### Storage Keys

Secret keys are namespaced per server URL:

```
kyber_secret_{namespace}_{userId}
dilithium_secret_{namespace}_{userId}
```

Where `namespace` = base64url(serverUrl) without padding.

## Message Payload Format

Before encryption, the plaintext is encoded as JSON by `PayloadCodec`:

```json
{
  "v": 1,
  "content": "Hello, world!",
  "reply_to": "optional_message_id",
  "attachments": [
    {
      "filename": "photo.jpg",
      "mime": "image/jpeg",
      "bytes_b64": "<base64-encoded file bytes>"
    }
  ]
}
```

Attachments are embedded directly in the encrypted payload (not stored as separate PocketBase files for encrypted messages).

## Encryption Protocol (Per Recipient)

For each recipient (including the sender), the following steps execute in `ChatScreen._sendMessage()`:

### Step 1: Create Message Record

A PocketBase `messages` record is created **first** to obtain a server-authoritative `created` timestamp:

```dart
body: {
  'chat': chatId,
  'sender': senderId,
  'recipient': recipientId,
  'edited': false,
  'deleted': false,
  'content': messageGroupId,  // 32-char hex client ID
  'attachments': [],
}
```

### Step 2: Build Associated Data (AAD)

```
AAD = UTF-8("v1|{chatType}|{chatId}|{timestampMs}")
```

The timestamp comes from the server `created` field, binding the ciphertext to a specific chat context and time.

### Step 3: KEM Encapsulation

```
(sharedSecret, kemCiphertext) = ML-KEM-512.encapsulate(recipientKyberPublicKey)
```

### Step 4: Session Key Derivation

```
sessionKey = HKDF-SHA256(
  secretKey: sharedSecret,
  nonce: randomSalt32(),        // 32 random bytes, unique per message copy
  info: UTF-8("pqc-protocol-v1"),
  outputLength: 32
)
```

### Step 5: AEAD Encryption

```
(nonce, ciphertext, authTag) = XChaCha20-Poly1305.encrypt(
  plaintext: payloadBlob,
  key: sessionKey,
  nonce: randomNonce,           // algorithm-generated nonce
  aad: AAD
)
```

### Step 6: Signature

A deterministic byte layout is constructed and signed with the sender's Dilithium secret key:

```
signableBytes = version(1 byte)
              + UTF-8(chatType)
              + UTF-8(senderId)
              + UTF-8(chatId)
              + int64BE(timestampMs)
              + salt
              + nonce
              + ciphertext
              + authTag

signature = Dilithium2.sign(signableBytes, senderDilithiumSecretKey)
```

### Step 7: Upload Encrypted Artifacts

The message record is updated with file fields:

| Field | Filename | Content |
|-------|----------|---------|
| `kem_ciphertext` | `kem_ct.bin` | KEM ciphertext bytes |
| `hkdf_salt` | `salt.bin` | HKDF salt (32 bytes) |
| `xc20_nonce` | `nonce.bin` | XChaCha20 nonce |
| `ciphertext` | `ciphertext.bin` | Encrypted payload |
| `auth_tag` | `auth_tag.bin` | Poly1305 MAC |
| `signature` | `sig.bin` | Dilithium signature |

## Decryption Protocol

Executed in `MessageCrypto.decryptFromRecordFiles()` during `ChatScreen._fetchMessages()`:

1. Download all encrypted file fields via `PbFileDownloader`
2. KEM decapsulate: `sharedSecret = ML-KEM-512.decapsulate(kemCiphertext, kyberSecretKey)`
3. Derive session key: same HKDF parameters (sharedSecret, salt, info)
4. AEAD decrypt: `plaintext = XChaCha20-Poly1305.decrypt(ciphertext, sessionKey, nonce, aad, authTag)`
5. Decode payload: `PayloadCodec.decode(plaintext)`
6. Verify signature: fetch sender's Dilithium public key, verify against signable bytes
7. Best-effort zeroization of `sharedSecret` and `sessionKeyBytes` after use

### Failure Handling

If decryption or verification fails, the message is **not rendered**. The code intentionally skips failures rather than showing corrupt or unverified content.

## Per-Recipient Message Duplication

Encrypted messages create **one PocketBase record per chat member** (including the sender). Each copy is encrypted to that member's Kyber public key.

**Why:**
- Each recipient needs artifacts encrypted to their own public key
- The server never has access to a single decryptable copy

**Message Group ID:**
- A random 32-character hex string (`_newClientMessageId()`) is stored in the `content` field
- All recipient copies share the same group ID
- Edit and delete operations find all copies by matching this ID

## Edit and Delete (Encrypted Messages)

`_rewriteEncryptedMessageForAllCopies()` handles both operations:

1. Find all message records in the current chat with the same `content` (group ID)
2. For each copy:
   - Re-encrypt the new payload (edited content or "This message was deleted.")
   - Re-sign with updated artifacts
   - Update file fields on the record
   - Set `edited` or `deleted` flags

This ensures all recipients see the updated or deleted state without storing plaintext on the server.

## Message Filtering

When fetching messages, the client filters to records where:
- `recipient` is empty (legacy/unencrypted), OR
- `recipient` equals the current user's ID

This prevents users from seeing copies encrypted for other recipients.

## Caching

| Cache | Location | Scope |
|-------|----------|-------|
| Public keys | `PublicKeyRepository._cache` | Per user ID, in-memory |
| Downloaded files | `PbFileDownloader._cache` | Per collection/record/filename, in-memory |

Caches are not persisted across app restarts.

## Security Properties

| Property | Status |
|----------|--------|
| End-to-end encryption | Yes — server sees only ciphertext |
| Post-quantum KEM | Yes — ML-KEM-512 |
| Post-quantum signatures | Yes — Dilithium2 |
| Forward secrecy | No — same long-term Kyber keypair per user |
| Key rotation | Partial — `key_version` and `key_rotated_at` fields exist but rotation logic is not implemented |
| Metadata protection | No — chat membership, timestamps, sender/recipient IDs are visible to server |
| Attachment encryption | Yes — embedded in encrypted payload |

## Threat Model Assumptions

- PocketBase server is **honest-but-curious** (stores data, may attempt to read it)
- Server cannot break ML-KEM-512 or Dilithium2
- Device secure storage is trusted (Android Keystore-backed via `flutter_secure_storage`)
- Client-side code is not tampered with

## Related Documentation

- [Architecture](./architecture.md) — Messaging flow diagrams
- [PocketBase Schema](./pocketbase-schema.md) — Field definitions for encrypted artifacts
- [State & Storage](./state-and-storage.md) — Secret key storage details
