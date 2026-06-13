# ⚡ Erebus

> Post-Quantum End-to-End Encrypted Messaging Platform built with Flutter, PocketBase, ML-KEM (Kyber), and Dilithium.

<p align="center">
  <img src="assets/app_logo.svg" width="160" alt="Erebus Logo">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?style=for-the-badge&logo=flutter" />
  <img src="https://img.shields.io/badge/PocketBase-Backend-orange?style=for-the-badge" />
  <img src="https://img.shields.io/badge/E2EE-Post--Quantum-success?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Platform-Android-black?style=for-the-badge" />
</p>

---

## Overview

**Erebus** is a secure messaging MVP designed around **Post-Quantum Cryptography (PQC)** and modern end-to-end encryption principles.

The application enables users to communicate through encrypted chats where messages and attachments are individually encrypted for each recipient using **ML-KEM-512 (Kyber)** and authenticated using **Dilithium2 signatures**.

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

```bash
git clone https://github.com/Erebus9456/erebus-frontend.git

cd erebus-frontend

flutter pub get

flutter run
```

---

## Build Releases

### Android APK

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

## Assets

```text
assets/
├── app_logo.svg
└── splash_lottie_logo_aninmation.json
```

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
