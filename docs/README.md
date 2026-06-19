# Erebus Documentation

Erebus is a Flutter chat application backed by **PocketBase** with **post-quantum end-to-end encryption (E2EE)** for messages and attachments. This documentation covers the Flutter client in this repository.

## Documentation Index

| Document | Description |
|----------|-------------|
| [Getting Started](./getting-started.md) | Prerequisites, installation, first run, and server setup |
| [Architecture](./architecture.md) | High-level system design, data flow, and component relationships |
| [Project Structure](./project-structure.md) | Directory layout and module responsibilities |
| [E2EE Cryptography](./e2ee-cryptography.md) | Post-quantum encryption design, algorithms, and message lifecycle |
| [PocketBase Schema](./pocketbase-schema.md) | Expected backend collections, fields, and API usage |
| [Screens & Features](./screens-and-features.md) | UI screens, user flows, and feature reference |
| [State & Storage](./state-and-storage.md) | Provider state, secure storage, and persistence |
| [Themes](./themes.md) | Theme system, available palettes, and customization |
| [Build & Deploy](./build-and-deploy.md) | Android builds, release configuration, and platform notes |
| [Dependencies](./dependencies.md) | Package inventory with purpose and version constraints |

## Quick Overview

### What Erebus Does

- **Multi-server support** — Add, edit, remove, and switch between PocketBase server URLs
- **Authentication** — Register, login, and logout with PocketBase users
- **Private & group chats** — Start 1:1 conversations or create named group chats
- **Encrypted messaging** — All messages and attachments encrypted per-recipient using post-quantum algorithms
- **Message features** — Replies, edit, delete, in-chat search, and file attachments (up to 200 MB)
- **Realtime updates** — Live chat list and message subscriptions via PocketBase realtime
- **Themes** — 50 selectable color themes persisted across sessions
- **Profile management** — Edit name, bio, status, and avatar

### Tech Stack at a Glance

| Layer | Technology |
|-------|------------|
| UI Framework | Flutter (Dart SDK ^3.10.1) |
| State Management | `provider` (ChangeNotifier) |
| Backend | PocketBase (`pocketbase` package) |
| Post-Quantum Crypto | `oqs` (ML-KEM-512, Dilithium2) |
| Symmetric Crypto | `cryptography` (XChaCha20-Poly1305, HKDF-SHA256) |
| Secure Storage | `flutter_secure_storage` |
| Preferences | `shared_preferences` |
| Platform | Android (primary; other platforms excluded from repo) |

### Default Server

The app ships with a default PocketBase server URL (`.onion` address) intended for Tor-based deployments. See [Getting Started](./getting-started.md) for connectivity requirements.

## Repository Scope

This repository contains **only the Flutter client**. PocketBase collection schemas, migrations, and server deployment are external to this project but are documented in [PocketBase Schema](./pocketbase-schema.md) based on what the client expects.
