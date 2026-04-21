import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketbase/pocketbase.dart';

class CustomSecureAuthStore extends AuthStore {
  CustomSecureAuthStore._({
    required String namespaceKey,
  })  : _tokenKey = 'pb_auth_token_$namespaceKey',
        _modelKey = 'pb_auth_model_$namespaceKey';

  late final FlutterSecureStorage _storage;
  final String _tokenKey;
  final String _modelKey;

  static Future<CustomSecureAuthStore> initialize({
    required String namespaceKey,
  }) async {
    final instance = CustomSecureAuthStore._(namespaceKey: namespaceKey)
      .._storage = const FlutterSecureStorage();

    // Listener fires every time the AuthStore state changes (login, logout, refresh)
    instance.onChange.listen((e) async {
      final model = e.model;
      if (model == null || !instance.isValid) {
        // Log out: Clear all session data from secure storage
        await instance._storage.delete(key: instance._tokenKey);
        await instance._storage.delete(key: instance._modelKey);
      } else if (model is RecordModel) {
        // Log in/Refresh: Write the token and the JSON-encoded model
        await instance._storage.write(key: instance._tokenKey, value: e.token);
        // Ensure the model is converted to JSON before storage
        await instance._storage.write(
          key: instance._modelKey,
          value: jsonEncode(model.toJson()),
        );
      }
    });

    return instance;
  }

  // Attempts to restore the session from secure storage and refresh the token
  Future<bool> restore({required PocketBase pb}) async {
    final token = await _storage.read(key: _tokenKey);
    final modelJson = await _storage.read(key: _modelKey);

    if (token == null) {
      return false;
    }

    // 1. Restore the state into the AuthStore's in-memory model
    save(
      token,
      modelJson == null ? null : RecordModel.fromJson(jsonDecode(modelJson)),
    );

    // 2. Attempt to refresh the token with the PocketBase server
    try {
      // Use the 'users' collection for refresh by default
      await pb.collection('users').authRefresh(); 
      return isValid;
    } on Exception {
      // If refresh fails (e.g., refresh token expired), clear storage
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _modelKey);
      return false;
    }
  }
}