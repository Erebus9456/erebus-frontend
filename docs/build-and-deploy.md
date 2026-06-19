# Build & Deploy

This project targets **Android** as its primary platform. Other platform directories (iOS, web, Linux, macOS, Windows) are excluded from the repository via `.gitignore`.

## Version

Defined in `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

| Component | Value | Used For |
|-----------|-------|----------|
| `1.0.0` | Version name | `versionName` (Android) |
| `1` | Build number | `versionCode` (Android) |

Override at build time:

```bash
flutter build apk --build-name=1.1.0 --build-number=2
```

## Debug Build

```bash
flutter run
```

Or explicitly:

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

## Release Build

### APK (direct install)

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### App Bundle (Google Play)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

## Android Configuration

### Application ID

```
com.example.erebusv3
```

Defined in `android/app/build.gradle.kts`. Change this before publishing to app stores.

### SDK Versions

Managed by Flutter's Gradle plugin:

```kotlin
compileSdk = flutter.compileSdkVersion
minSdk = flutter.minSdkVersion
targetSdk = flutter.targetSdkVersion
ndkVersion = flutter.ndkVersion
```

The `oqs` package requires native library support — ensure your target devices support the NDK architecture.

### Java / Kotlin

```kotlin
sourceCompatibility = JavaVersion.VERSION_17
targetCompatibility = JavaVersion.VERSION_17
jvmTarget = "17"
```

### Signing

Currently uses debug signing for release builds:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

For production, configure a release keystore:

1. Generate a keystore:
   ```bash
   keytool -genkey -v -keystore erebus-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias erebus
   ```

2. Create `android/key.properties`:
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=erebus
   storeFile=../erebus-release.jks
   ```

3. Update `android/app/build.gradle.kts` to reference the keystore

> Do not commit `key.properties` or `.jks` files to version control.

### AndroidManifest

**File:** `android/app/src/main/AndroidManifest.xml`

| Setting | Value | Purpose |
|---------|-------|---------|
| `android:label` | `Erebus` (`@string/app_name`) | App display name on launcher |
| `INTERNET` | Permission | Required for release builds to reach PocketBase |
| `usesCleartextTraffic` | `true` | Allow HTTP connections (non-TLS PocketBase servers) |
| `WRITE_EXTERNAL_STORAGE` | Permission | Legacy file storage access |

> **Note:** `INTERNET` must be in the **main** manifest. Debug/profile manifests alone are not merged into release builds.

## Native Dependencies

The `oqs` package bundles liboqs native libraries for post-quantum cryptography. These are compiled per ABI architecture (arm64-v8a, armeabi-v7a, x86_64) during the Flutter build.

`cryptography_flutter` may use platform-native implementations for AES/ChaCha operations.

## Build Optimization

### Obfuscation (optional)

```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
```

### Split APKs by ABI

```bash
flutter build apk --release --split-per-abi
```

Produces smaller per-architecture APKs:
- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`
- `app-x86_64-release.apk`

## Pre-Release Checklist

- [ ] Update `version` in `pubspec.yaml`
- [ ] Change `applicationId` from `com.example.erebusv3`
- [ ] Configure release signing keystore
- [ ] Verify `assets/` directory contains required images
- [ ] Test on physical device with target PocketBase server
- [ ] Test E2EE message send/receive/decrypt cycle
- [ ] Test server switching and auth isolation
- [ ] Review `usesCleartextTraffic` — disable if all servers use HTTPS
- [ ] Remove or gate debug `print` statements if desired

## CI/CD Considerations

Example GitHub Actions workflow steps:

```yaml
- uses: subosito/flutter-action@v2
  with:
    channel: stable
- run: flutter pub get
- run: flutter analyze
- run: flutter build apk --release
```

Note: Tests are gitignored in this repo. Add a `test/` directory if CI testing is needed.

## Platform Limitations

| Platform | Status |
|----------|--------|
| Android | Supported (primary) |
| iOS | Not in repo (gitignored) |
| Web | Not in repo (gitignored) |
| Linux | Not in repo (gitignored) |
| macOS | Not in repo (gitignored) |
| Windows | Not in repo (gitignored) |

To add iOS support, run `flutter create --platforms=ios .` and configure signing.

## Related Documentation

- [Getting Started](./getting-started.md) — Development setup
- [Dependencies](./dependencies.md) — Native package requirements
- [Project Structure](./project-structure.md) — Android directory layout
