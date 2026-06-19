# PocketBase Schema

This document describes the PocketBase collections and fields that the Erebus Flutter client expects. The backend schema is **not included in this repository** — use this as a reference when setting up or validating your PocketBase instance.

## Collections Overview

| Collection | Auth | Purpose |
|------------|------|---------|
| `users` | Yes (auth collection) | User accounts, profiles, E2EE public keys |
| `chats` | Yes | Private and group conversations |
| `messages` | Yes | Chat messages (encrypted artifacts as file fields) |

## `users` Collection

PocketBase's built-in auth collection, extended with E2EE and profile fields.

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `username` | Text | Yes | Unique username (used for login and search) |
| `email` | Email | No | Email address (visibility controlled by `emailVisibility`) |
| `emailVisibility` | Bool | No | Whether email is visible to other users |
| `password` | Text | Yes | Hashed by PocketBase |
| `passwordConfirm` | Text | Yes | Required on create |
| `name` | Text | No | Display name |
| `bio` | Text | No | User biography |
| `avatar` | File | No | Profile picture |
| `status` | Select/Text | No | One of: `online`, `offline`, `away`, `busy` |
| `kyber_public_key` | File | Yes* | ML-KEM-512 public key (binary) |
| `dilithium_public_key` | File | Yes* | Dilithium2 public key (binary) |
| `key_version` | Number | Yes | E2EE key version (client sets `1` on create) |
| `key_rotated_at` | Date | Yes | ISO 8601 timestamp of last key rotation |

> *Required after first login when `KeyManager.ensureUserKeys()` uploads keys. Set as required in PocketBase migration with no default so registration must include them, or allow empty initially.

### Client Operations

| Operation | Method | Used In |
|-----------|--------|---------|
| Register | `collection('users').create(body)` | `AuthProvider.register()` |
| Login | `collection('users').authWithPassword(identity, password)` | `AuthProvider.login()` |
| Refresh | `collection('users').authRefresh()` | `CustomSecureAuthStore.restore()` |
| Get user | `collection('users').getOne(userId)` | `KeyManager`, `PublicKeyRepository` |
| Search users | `collection('users').getList(filter: 'username = "..."')` | `HomeScreen`, `GroupCreationDialog` |
| Update profile | `collection('users').update(userId, body, files)` | `ProfileScreen`, `KeyManager` |

### Registration Body

```json
{
  "username": "alice",
  "emailVisibility": true,
  "password": "securepassword",
  "passwordConfirm": "securepassword",
  "key_version": 1,
  "key_rotated_at": "2026-06-18T12:00:00.000Z"
}
```

## `chats` Collection

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | Select | Yes | `"private"` or `"group"` |
| `title` | Text | No | Group name (required for groups, empty for private) |
| `members` | Relation (users) | Yes | Array of user IDs (multi-select) |
| `last_message` | Date | No | Updated on each new message for sort ordering |
| `updated` | Date | Auto | PocketBase auto-managed |

### Private Chat Creation

```json
{
  "type": "private",
  "members": ["userId1", "userId2"]
}
```

Duplicate check filter:
```
type = "private" && members ~ "userId1" && members ~ "userId2"
```

### Group Chat Creation

```json
{
  "type": "group",
  "title": "My Group",
  "members": ["creatorId", "memberId1", "memberId2"]
}
```

Duplicate check filter:
```
type = "group" && title = "My Group"
```

### Client Operations

| Operation | Method | Used In |
|-----------|--------|---------|
| List chats | `getList(filter: 'members ~ "userId"', expand: 'members', sort: '-last_message,-updated')` | `HomeScreen` |
| Create chat | `create(body)` | `HomeScreen`, `GroupCreationDialog` |
| Update last_message | `update(chatId, body: {'last_message': iso8601})` | `ChatScreen._sendMessage()` |
| Realtime | `realtime.subscribe('chats', callback)` | `HomeScreen` |

### List Rule Suggestion

Users should only see chats they are a member of:

```
@request.auth.id != "" && members.id ?= @request.auth.id
```

## `messages` Collection

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `chat` | Relation (chats) | Yes | Parent chat ID |
| `sender` | Relation (users) | Yes | Message sender |
| `recipient` | Relation (users) | No | Target recipient (set for encrypted per-recipient copies) |
| `content` | Text | Yes | Plaintext (legacy) or 32-char hex group ID (encrypted) |
| `reply_to` | Relation (messages) | No | Referenced message for replies |
| `edited` | Bool | No | Whether message was edited |
| `deleted` | Bool | No | Whether message was soft-deleted |
| `attachments` | File (multi) | No | Legacy plaintext attachments (empty for encrypted) |
| `kem_ciphertext` | File | No | ML-KEM-512 ciphertext |
| `hkdf_salt` | File | No | HKDF salt (32 bytes) |
| `xc20_nonce` | File | No | XChaCha20 nonce |
| `ciphertext` | File | No | AEAD ciphertext |
| `auth_tag` | File | No | Poly1305 authentication tag |
| `signature` | File | No | Dilithium2 signature |
| `created` | Date | Auto | Server timestamp (used in AAD) |

### Encrypted Message Record (Initial Create)

```json
{
  "chat": "chatRecordId",
  "sender": "senderUserId",
  "recipient": "recipientUserId",
  "edited": false,
  "deleted": false,
  "content": "a1b2c3d4e5f6789012345678abcdef01",
  "attachments": [],
  "reply_to": "optionalMessageId"
}
```

Followed by an `update()` with encrypted file fields.

### Client Operations

| Operation | Method | Used In |
|-----------|--------|---------|
| List messages | `getFullList(filter: 'chat = "chatId"', expand: 'sender,reply_to,reply_to.sender', sort: 'created')` | `ChatScreen` |
| Create message | `create(body)` then `update(id, files)` | `ChatScreen._sendMessage()` |
| Edit message | `update(id, body)` or re-encrypt all copies | `ChatScreen._editMessage()` |
| Delete message | `update(id, body)` or re-encrypt all copies | `ChatScreen._deleteMessage()` |
| Realtime | `realtime.subscribe('messages', callback)` | `ChatScreen` |

### List Rule Suggestion

Users should see messages in chats they belong to:

```
@request.auth.id != "" && chat.members.id ?= @request.auth.id
```

## File Access

Files are downloaded via authenticated HTTP:

```
GET {baseUrl}/api/files/{collection}/{recordId}/{filename}
Authorization: Bearer {token}
```

Implemented in `PbFileDownloader.downloadFile()`.

Avatar and attachment URLs follow the same pattern:
```
{baseUrl}/api/files/users/{userId}/{avatarFilename}
```

## Realtime Events

PocketBase realtime delivers SSE events with this structure:

```json
{
  "action": "create" | "update" | "delete",
  "record": { /* full record JSON */ }
}
```

The client handles both `String` (raw JSON) and `Map` event data formats.

## API Health Check

`ServerSelectorCard` tests connectivity via:

```
GET {serverUrl}/api/health
```

## PocketBase Setup Checklist

1. Create `chats` collection with fields above
2. Create `messages` collection with fields above
3. Extend `users` collection with E2EE and profile fields
4. Configure collection rules for auth-based access
5. Enable realtime on `chats` and `messages`
6. Ensure file storage is configured (local or S3)
7. Set appropriate max file size (client allows up to 200 MB attachments)

## Related Documentation

- [E2EE Cryptography](./e2ee-cryptography.md) — How encrypted fields are produced
- [Architecture](./architecture.md) — API interaction patterns
- [Getting Started](./getting-started.md) — Server connectivity
