import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class E2eeSecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String kyberSecretKey(String userId, {String? namespace}) {
    if (namespace == null || namespace.isEmpty) return 'kyber_secret_$userId';
    return 'kyber_secret_${namespace}_$userId';
  }

  static String dilithiumSecretKey(String userId, {String? namespace}) {
    if (namespace == null || namespace.isEmpty) {
      return 'dilithium_secret_$userId';
    }
    return 'dilithium_secret_${namespace}_$userId';
  }

  Future<void> writeBase64(String key, String value) => _storage.write(
        key: key,
        value: value,
      );

  Future<String?> readBase64(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);
}

