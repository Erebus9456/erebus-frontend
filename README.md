<<<<<<< Updated upstream
# ⚡ Erebus

> Post-Quantum End-to-End Encrypted Messaging Platform built with Flutter, PocketBase, ML-KEM (Kyber), and Dilithium.
=======
56# Erebus

Erebus is a Flutter chat backed by **PocketBase** with **post-quantum end-to-end encryption (E2EE)** for messages and attachments.
>>>>>>> Stashed changes

<p align="center">
  <img src="assets/app_logo.svg" width="160" alt="Erebus Logo">
</p>

<<<<<<< Updated upstream
<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?style=for-the-badge&logo=flutter" />
  <img src="https://img.shields.io/badge/PocketBase-Backend-orange?style=for-the-badge" />
  <img src="https://img.shields.io/badge/E2EE-Post--Quantum-success?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Platform-Android-black?style=for-the-badge" />
</p>

---
=======
## Documentation

Full project documentation lives in [`docs/`](docs/README.md):

| Document | Description |
|----------|-------------|
| [Getting Started](docs/getting-started.md) | Prerequisites, installation, first run, and troubleshooting |
| [Architecture](docs/architecture.md) | System design, data flows, and security model |
| [Project Structure](docs/project-structure.md) | Directory layout and module responsibilities |
| [E2EE Cryptography](docs/e2ee-cryptography.md) | Post-quantum encryption protocol and message lifecycle |
| [PocketBase Schema](docs/pocketbase-schema.md) | Expected backend collections, fields, and API usage |
| [Screens & Features](docs/screens-and-features.md) | UI screens, navigation, and feature reference |
| [State & Storage](docs/state-and-storage.md) | Provider state, secure storage, and persistence |
| [Themes](docs/themes.md) | Theme system and available palettes |
| [Build & Deploy](docs/build-and-deploy.md) | Android builds, signing, and release checklist |
| [Dependencies](docs/dependencies.md) | Package inventory with usage context |

## What this app does

- **Multi-server support** — Pick, add, edit, and remove PocketBase base URLs from the login screen
- **Auth** — Register, login, and logout using PocketBase users
- **Chat list** — Loads your chats from PocketBase and updates via realtime subscriptions
- **Messaging** — All messages and attachments are **encrypted per-recipient**; supports **replies**, **edit/delete**, **search**, and **attachments** (up to 200 MB)
- **Group chats** — Create named group conversations with multiple members
- **Themes** — 50 selectable color themes persisted via `shared_preferences`
- **Profile** — Edit name, bio, status, and avatar
>>>>>>> Stashed changes

## Overview

<<<<<<< Updated upstream
**Erebus** is a secure messaging MVP designed around **Post-Quantum Cryptography (PQC)** and modern end-to-end encryption principles.
=======
- **Flutter** + `provider` for app state
- **PocketBase** (`pocketbase` package) for auth, collections, realtime, and file storage
- **Secure persistence**:
  - PocketBase auth state persisted via `flutter_secure_storage` (`CustomSecureAuthStore`)
  - E2EE secrets stored locally via `E2eeSecureStorage`
- **Crypto (E2EE)**:
  - **ML-KEM-512 (Kyber)** via `oqs` for key encapsulation (shared secret per recipient)
  - **Dilithium2** via `oqs` for message signatures
  - **HKDF-SHA256** to derive a 32-byte session key from the shared secret
  - **XChaCha20-Poly1305** (`cryptography`) for AEAD encryption of the message payload

See [E2EE Cryptography](docs/e2ee-cryptography.md) for the full protocol.
>>>>>>> Stashed changes

The application enables users to communicate through encrypted chats where messages and attachments are individually encrypted for each recipient using **ML-KEM-512 (Kyber)** and authenticated using **Dilithium2 signatures**.

<<<<<<< Updated upstream
This repository contains the complete Flutter client:

* Modern Flutter UI
* Authentication & session management
* PocketBase integration
* Realtime chat synchronization
* Post-Quantum E2EE implementation
* Secure local key management

---

## Key Features

### Secure by Design

* 🔐 Post-Quantum End-to-End Encryption
* ✍️ Dilithium2 digital signatures
* 🛡️ XChaCha20-Poly1305 authenticated encryption
* 🔑 HKDF-SHA256 session key derivation
* 📱 Device-local secure key storage

### Messaging

* 💬 Realtime conversations
* 📎 Encrypted attachments
* ↩️ Message replies
* ✏️ Message editing
* 🗑️ Message deletion
* 🔍 Message search

### Platform

* 🌐 Multi-server PocketBase support
* ⚡ Realtime synchronization
* 🎨 Persistent theme selection
* 🔒 Secure authentication persistence

---

## Architecture

```text
┌────────────────────┐
│   Flutter Client   │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│    PocketBase      │
│ Auth • Realtime    │
│ Storage • Records  │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│  E2EE Layer        │
│ ML-KEM-512         │
│ Dilithium2         │
│ HKDF-SHA256        │
│ XChaCha20Poly1305  │
└────────────────────┘
```

---

## Technology Stack

| Layer                  | Technology               |
| ---------------------- | ------------------------ |
| Frontend               | Flutter                  |
| State Management       | Provider                 |
| Backend                | PocketBase               |
| Authentication         | PocketBase Auth          |
| Storage                | PocketBase File Storage  |
| Realtime               | PocketBase Subscriptions |
| Secure Storage         | flutter_secure_storage   |
| PQ Encryption          | ML-KEM-512 (Kyber)       |
| Digital Signatures     | Dilithium2               |
| Session Key Derivation | HKDF-SHA256              |
| Symmetric Encryption   | XChaCha20-Poly1305       |

---

## Cryptography Pipeline

### Identity

Each user owns:

* ML-KEM-512 keypair
* Dilithium2 keypair

Private keys remain on the device.

Public keys are published to PocketBase for recipient discovery.

### Encryption Flow

```text
Message
   │
   ▼
Payload Encoding
   │
   ▼
ML-KEM Encapsulation
   │
   ▼
Shared Secret
   │
   ▼
HKDF-SHA256
   │
   ▼
Session Key
   │
   ▼
XChaCha20-Poly1305
   │
   ▼
Ciphertext
   │
   ▼
Dilithium Signature
```

### Decryption Flow

```text
Encrypted Payload
        │
        ▼
ML-KEM Decapsulation
        │
        ▼
Shared Secret
        │
        ▼
HKDF-SHA256
        │
        ▼
Session Key
        │
        ▼
XChaCha20-Poly1305
        │
        ▼
Plaintext
        │
        ▼
Dilithium Verification
```

---

## Getting Started

### Prerequisites

* Flutter SDK
* Dart SDK `^3.10.1`
* Running PocketBase instance
* Network connectivity to your PocketBase deployment

### Installation
=======
- Flutter SDK (Dart SDK constraint in `pubspec.yaml` is `^3.10.1`)
- A running PocketBase server reachable from the device/emulator
  - The default server is a `.onion` address; if your deployment requires Tor, ensure the device has connectivity before logging in. See [Getting Started](docs/getting-started.md).

## Quick start
>>>>>>> Stashed changes

```bash
git clone https://github.com/Erebus9456/erebus-frontend.git

cd erebus-frontend

flutter pub get

flutter run
```

<<<<<<< Updated upstream
---
=======
On first launch:

1. Pick a PocketBase server in the **Server Selector** on the login screen
2. Register or login
3. After login, the app ensures your **E2EE keypair material** exists locally and your **public keys** are uploaded
>>>>>>> Stashed changes

## Build Releases

<<<<<<< Updated upstream
### Android APK

=======
>>>>>>> Stashed changes
```bash
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle

```bash
flutter build appbundle --release
```

<<<<<<< Updated upstream
Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

---

## Project Structure

```text
lib/
├── classes/
│   └── auth_provider.dart
│
├── screens/
│   ├── auth/
│   └── ui/
│
├── services/
│   └── e2ee/
│       ├── key_manager.dart
│       ├── message_crypto.dart
│       ├── signature_service.dart
│       ├── public_key_repository.dart
│       ├── payload_codec.dart
│       ├── pb_file_downloader.dart
│       └── secure_storage.dart
│
└── main.dart
```

---

## Application Flow

### Startup

```text
Launch
   │
   ▼
Splash Screen
   │
   ▼
Restore Auth
   │
   ├── Authenticated → Home
   │
   └── Not Authenticated → Login
```

### Authentication

1. User selects PocketBase server
2. User registers or logs in
3. E2EE keys are generated if missing
4. Public keys are uploaded
5. User enters secure messaging environment

---

## Security Model

### Private Keys

Stored exclusively on the user's device using secure storage.

### Public Keys

Published to PocketBase for recipient key discovery.

### Message Storage

Messages are stored encrypted.

The server never receives plaintext content or encryption keys.

### Recipient Isolation

Each recipient receives an independently encrypted copy of a message using their own public key.

---
=======
Output paths:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

See [Build & Deploy](docs/build-and-deploy.md) for signing, versioning, and release checklist.

## Project layout

```
lib/
├── main.dart              # App entry point
├── classes/               # AuthProvider, themes, server/auth storage
├── screens/               # UI (auth, home, chat, profile, themes)
└── services/e2ee/         # Post-quantum encryption module
```

See [Project Structure](docs/project-structure.md) for the full breakdown.
>>>>>>> Stashed changes

## Assets

```text
assets/
├── app_logo.svg
└── splash_lottie_logo_aninmation.json
```

<<<<<<< Updated upstream
---

## Notes & Assumptions

* This repository contains the Flutter client only.
* PocketBase schema and migrations are maintained separately.
* The application expects collections such as:

  * `users`
  * `chats`
  * `messages`
* Message encryption is performed per recipient.
* Public key discovery is handled through PocketBase user records.

### Backend Repository

**Backend Source:** https://github.com/Erebus9456/erebus-backend

---

<p align="center">
  Built with Flutter, PocketBase, and Post-Quantum Cryptography.
</p>
=======
## Notes

- This repository documents the **Flutter client only**. PocketBase collection schemas and server deployment are external; the client expects `users`, `chats`, and `messages` collections as described in [PocketBase Schema](docs/pocketbase-schema.md).
- This project targets **Android**; other platform folders are excluded from the repo.
>>>>>>> Stashed changes
