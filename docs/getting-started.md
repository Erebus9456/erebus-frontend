# Getting Started

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Flutter SDK | Install from [flutter.dev](https://flutter.dev/docs/get-started/install). Dart SDK `^3.10.1` per `pubspec.yaml` |
| Android toolchain | Required for building/running (this repo is Android-only; iOS/web/desktop folders are gitignored) |
| PocketBase server | A running instance reachable from your device or emulator |
| Tor (optional) | Default server URL is a `.onion` address; Tor connectivity may be required depending on deployment |

Verify your environment:

```bash
flutter doctor
```

## Installation

Clone the repository and install dependencies:

```bash
cd erebusv3
flutter pub get
```

## Running Locally

```bash
flutter run
```

For a specific device:

```bash
flutter devices
flutter run -d <device_id>
```

## First Launch Walkthrough

### 1. Splash Screen

While `AuthProvider` restores any persisted session, the app displays `SplashPage` with the selected theme's logo and a loading indicator.

### 2. Server Selection

On the login screen, use the **Server Selector** card to:

- Pick an existing server from the dropdown
- **Test Server** — Ping the selected URL's `/api/health` endpoint
- **Manage Servers** — Add, edit (URL + nickname), or remove servers

The default server is:

```
http://a2zrowasng3umdxvmv6dz3dwh7u3j36dzvvhyd77jg34qhfdevyxxaad.onion
```

> **Tor note:** If using the default `.onion` server, ensure your device or emulator has Tor routing configured before attempting login. Connection errors surface messages referencing Tor connectivity.

### 3. Register or Login

**Register** (`RegisterScreen`):
- Username (used as identity for login)
- Password (minimum 8 characters)
- Password confirmation
- On success: auto-login → E2EE key generation → navigate to Home

**Login** (`LoginScreen`):
- Username or email + password
- On success: `ensureE2eeKeysReady()` runs → navigate to Home

### 4. E2EE Key Bootstrap

After authentication, the app automatically:

1. Checks for local Kyber + Dilithium secret keys in secure storage
2. Checks for uploaded public keys on the user record in PocketBase
3. If missing, generates new keypairs and uploads public keys to the server

Secret keys **never leave the device**.

### 5. Start Chatting

From `HomeScreen`:
- Tap **+** (FAB) or **Start New Chat** to search for a user by exact username
- Tap the group icon in the app bar to create a group chat
- Tap any chat to open `ChatScreen`

## Troubleshooting

| Symptom | Likely Cause | Action |
|---------|--------------|--------|
| "Unable to connect to PocketBase" | Server unreachable or Tor not connected | Verify server health; check Tor; try **Test Server** |
| "Login failed. Invalid username or password." | Wrong credentials | Re-enter credentials; confirm correct server |
| "OQS algorithms unavailable" | Native OQS library not available on platform | Run on a supported Android device/emulator |
| Messages not appearing | Decryption or signature verification failed | Check sender has uploaded public keys; see [E2EE Cryptography](./e2ee-cryptography.md) |
| Missing assets / splash errors | `assets/` folder not present | Ensure theme image assets exist under `assets/` |

## Development Tips

- Debug logging is enabled in several screens (`avoid_print` ignored in key files)
- Pull-to-refresh on the chat list re-fetches conversations
- Theme can be changed from the drawer → Settings → Toggle Theme
- `usesCleartextTraffic` is enabled in `AndroidManifest.xml` for HTTP servers

## Next Steps

- [Architecture](./architecture.md) — Understand how components fit together
- [PocketBase Schema](./pocketbase-schema.md) — Set up the backend collections
- [E2EE Cryptography](./e2ee-cryptography.md) — Deep dive into the encryption protocol
