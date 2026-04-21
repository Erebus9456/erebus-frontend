# Erebus (Flutter MVP) — `erebusv3`

Erebus is a Flutter chat MVP backed by **PocketBase** with **post-quantum end‑to‑end encryption (E2EE)** for messages and attachments.

This repository contains the Flutter client (UI + crypto + PocketBase integration).

## What this app does

- **Multi-server support**: pick/add/remove PocketBase base URLs from the login screen.
- **Auth**: register/login/logout using PocketBase users.
- **Chat list**: loads your chats from PocketBase and updates via realtime subscriptions.
- **Messaging**:
  - all messages / attatchments are **encrypted per-recipient**
  - supports **replies**, **edit/delete**, **search**, and **attachments**
- **Themes**: theme selection persisted via `shared_preferences`.

## Tech stack

- **Flutter** + `provider` for app state
- **PocketBase** (`pocketbase` package) for auth, collections, realtime, and file storage
- **Secure persistence**:
  - PocketBase auth state persisted via `flutter_secure_storage` (`CustomSecureAuthStore`)
  - E2EE secrets stored locally via `E2eeSecureStorage`
- **Crypto (E2EE)**:
  - **ML‑KEM‑512 (Kyber)** via `oqs` for key encapsulation (shared secret per recipient)
  - **Dilithium2** via `oqs` for message signatures
  - **HKDF‑SHA256** to derive a 32‑byte session key from the shared secret
  - **XChaCha20‑Poly1305** (`cryptography`) for AEAD encryption of the message payload

## Prerequisites

- Flutter SDK (Dart SDK constraint in `pubspec.yaml` is `^3.10.1`)
- A running PocketBase server reachable from the device/emulator
  - Your UI hints mention Tor; if your deployment requires it, ensure the device has connectivity to the `.onion` / proxy route before logging in.

## Quick start (run locally)

```bash
flutter pub get
flutter run
```

On first launch:
- Pick a PocketBase server in the **Server Selector** on the login screen.
- Register or login.
- After login, the app ensures your **E2EE keypair material** exists locally and your **public keys** are uploaded.

## Build / release

### Android (APK / App Bundle)

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

Output paths:
- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`


## Project structure (high-signal)

- `lib/main.dart`
  - bootstraps `provider` state: `ThemeNotifier` + `AuthProvider`
  - decides initial route: **Splash** → (**Home** if authenticated, else **Login**)
- `lib/classes/auth_provider.dart`
  - owns the PocketBase client (`pb`) and server selection
  - restores persisted auth, exposes `isAuthenticated`, and triggers UI navigation via `notifyListeners()`
  - ensures E2EE keys exist after login (`ensureE2eeKeysReady`)
- `lib/screens/auth/`
  - `login_screen.dart`: login form + server selector
  - `register_screen.dart`: user registration
  - `server_selector_card.dart`: manage base URL selection
- `lib/screens/ui/`
  - `home_screen.dart`: chat list + realtime updates + navigation to chat
  - `chat_screen.dart`: message list + decrypt/verify + send/edit/delete/search + attachments
- `lib/services/e2ee/`
  - `key_manager.dart`: generates/stores secrets, uploads public keys to PocketBase
  - `message_crypto.dart`: KEM → HKDF → XChaCha20-Poly1305 encrypt/decrypt helpers
  - `signature_service.dart`: Dilithium signing + verification helpers
  - `public_key_repository.dart`: loads user public keys from PocketBase
  - `payload_codec.dart`: encodes/decodes the plaintext payload (text, reply reference, attachments bytes)
  - `pb_file_downloader.dart`: downloads PocketBase “file fields” as bytes
  - `secure_storage.dart`: local secure storage key naming + read/write helpers

## App flow (screens + state)

### Startup

- `main()` loads the last selected theme from `shared_preferences`.
- `AuthProvider` initializes:
  - loads known PocketBase servers + selected server
  - builds the PocketBase client with a secure auth store
  - restores auth (if a prior session exists)
- While restoring, the app shows `SplashPage`.

### Login / Register

- `LoginScreen` calls `authProvider.login(identity, password)`.
- On success, `AuthProvider` calls `ensureE2eeKeysReady()` which:
  - makes sure this device has the local secret keys stored
  - ensures the matching public keys exist on the user record server-side

### Home (chat list)

- `HomeScreen` queries PocketBase `chats` filtered by membership and sorts by recency.
- It subscribes to realtime updates on `chats` and refetches when the user is affected.

### Chat (messages)

`ChatScreen` is responsible for:
- fetching message records for a chat
- decrypting + verifying encrypted messages
- sending encrypted messages (and optional attachments)
- updating/deleting messages (including encrypted messages across recipients)

## E2EE design (how the crypto works in this codebase)

This app uses a **hybrid E2EE** approach:

1. **Identity keys per user**
   - On device, `KeyManager` generates:
     - **Kyber (ML‑KEM‑512)** keypair for KEM (encryption key agreement)
     - **Dilithium2** keypair for signatures (authenticity)
   - **Secret keys stay on device** (stored using secure storage).
   - **Public keys are uploaded** to the user record in PocketBase (as file fields).

2. **Encrypting a message (per recipient)**
   - The plaintext payload (text, reply id, attachments bytes) is encoded via `PayloadCodec`.
   - For each recipient:
     - KEM encapsulation using the recipient’s Kyber public key → `sharedSecret` + `kemCiphertext`
     - HKDF-SHA256 derives a 32‑byte session key (salt is random per message copy)
     - XChaCha20‑Poly1305 encrypts the payload using:
       - random nonce
       - **AAD** built from `v1|chatType|chatId|timestampMs`
     - A Dilithium signature is produced over a deterministic “signable” byte layout containing the critical fields (chat context + salt/nonce/ciphertext/authTag).
   - Storage model:
     - a PocketBase `messages` record is created first (to get server timestamp)
     - the encrypted artifacts are uploaded as **file fields** (`kem_ciphertext`, `hkdf_salt`, `xc20_nonce`, `ciphertext`, `auth_tag`, `signature`)

3. **Decrypting + verifying**
   - The client downloads the encrypted file fields as bytes.
   - It decapsulates using the local Kyber secret key and derives the session key (HKDF).
   - It decrypts with XChaCha20‑Poly1305 using the same AAD.
   - It fetches the sender’s Dilithium public key and verifies the signature.
   - If decrypt or verify fails, the message is **not rendered** (the code intentionally skips failures).

4. **Why messages are duplicated**
   - For encrypted sends, the app writes **one message record per recipient** (including yourself) so each recipient has artifacts encrypted to their keys.
   - A random client-side “message group id” is stored in the `content` field for encrypted messages so edit/delete can be applied across all recipient copies **without storing plaintext**.

## Assets

- `assets/app_logo.svg`
- `assets/splash_lottie_logo_aninmation.json`

## Notes / assumptions

- This README documents the Flutter client only. PocketBase collection schema/migrations are not included here, but the client expects collections like `users`, `chats`, and `messages` with the fields referenced in code.

