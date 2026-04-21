import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:erebusv3/classes/secure_auth_store.dart';
import 'package:erebusv3/classes/server_store.dart';
import 'package:erebusv3/services/e2ee/key_manager.dart';

class AuthProvider extends ChangeNotifier {
  // 1. PocketBase Client, server list, and auth store
  late PocketBase pb;
  late CustomSecureAuthStore _authStore;
  final ServerStore _serverStore = ServerStore();
  List<ServerEntry> _servers = <ServerEntry>[];
  String _baseUrl = ServerStore.defaultServer;

  List<ServerEntry> get serverEntries => List.unmodifiable(_servers);
  List<String> get servers => List.unmodifiable(_servers.map((e) => e.url).toList());
  String get selectedServer => _baseUrl;
  String get e2eeKeyNamespace => _serverStore.namespaceForServer(_baseUrl);

  // 2. Auth State Checkers
  bool get isAuthenticated => pb.authStore.isValid;
  RecordModel? get currentUser => pb.authStore.model;
  
  // State for initial loading (checking session on app start)
  bool _isCheckingAuth = true;
  bool get isCheckingAuth => _isCheckingAuth;

  AuthProvider() {
    // Start initialization when the provider is created
    _initializePb();
  }

  Future<void> _initializePb() async {
    _servers = await _serverStore.loadServers();
    _baseUrl = await _serverStore.loadSelectedServer(servers: _servers);
    await _rebuildPocketBase();
    _isCheckingAuth = false;
    notifyListeners();
  }

  Future<void> _rebuildPocketBase() async {
    _authStore = await CustomSecureAuthStore.initialize(
      namespaceKey: _serverStore.namespaceForServer(_baseUrl),
    );
    pb = PocketBase(_baseUrl, authStore: _authStore);
    pb.authStore.onChange.listen((event) {
      notifyListeners();
    });
    await _authStore.restore(pb: pb);
  }

  Future<void> setSelectedServer(String serverUrl) async {
    final normalized = _serverStore.normalizeUrl(serverUrl);
    if (normalized.isEmpty || normalized == _baseUrl) return;
    _isCheckingAuth = true;
    notifyListeners();
    _baseUrl = normalized;
    if (!_servers.any((e) => e.url == normalized)) {
      _servers = <ServerEntry>[
        ..._servers,
        ServerEntry(
          url: normalized,
          nickname: _serverStore.defaultNickname(normalized),
        ),
      ];
    }
    await _serverStore.saveServers(
      servers: _servers,
      selectedServer: _baseUrl,
    );
    await _rebuildPocketBase();
    _isCheckingAuth = false;
    notifyListeners();
  }

  Future<void> addServer(String serverUrl, {String? nickname}) async {
    final normalized = _serverStore.normalizeUrl(serverUrl);
    if (normalized.isEmpty || _servers.any((e) => e.url == normalized)) return;
    final name = (nickname ?? '').trim();
    _servers = <ServerEntry>[
      ..._servers,
      ServerEntry(
        url: normalized,
        nickname: name.isNotEmpty ? name : _serverStore.defaultNickname(normalized),
      ),
    ];
    await _serverStore.saveServers(
      servers: _servers,
      selectedServer: _baseUrl,
    );
    notifyListeners();
  }

  Future<void> updateServer({
    required String oldUrl,
    required String newUrl,
    String? nickname,
  }) async {
    final normalized = _serverStore.normalizeUrl(newUrl);
    if (normalized.isEmpty) return;
    final idx = _servers.indexWhere((e) => e.url == oldUrl);
    if (idx == -1) return;
    final name = (nickname ?? _servers[idx].nickname).trim();
    final updated = ServerEntry(
      url: normalized,
      nickname: name.isNotEmpty ? name : _serverStore.defaultNickname(normalized),
    );
    final mutable = <ServerEntry>[..._servers];
    mutable[idx] = updated;
    final deduped = <String, ServerEntry>{};
    for (final e in mutable) {
      deduped[e.url] = e;
    }
    _servers = deduped.values.toList();
    if (_baseUrl == oldUrl) {
      _baseUrl = normalized;
      await _serverStore.saveServers(
        servers: _servers,
        selectedServer: _baseUrl,
      );
      _isCheckingAuth = true;
      notifyListeners();
      await _rebuildPocketBase();
      _isCheckingAuth = false;
    } else {
      await _serverStore.saveServers(
        servers: _servers,
        selectedServer: _baseUrl,
      );
    }
    notifyListeners();
  }

  Future<void> removeServer(String url) async {
    if (_servers.length <= 1) return;
    _servers = _servers.where((s) => s.url != url).toList();
    if (_baseUrl == url) {
      _baseUrl = _servers.first.url;
      _isCheckingAuth = true;
      notifyListeners();
      await _serverStore.saveServers(
        servers: _servers,
        selectedServer: _baseUrl,
      );
      await _rebuildPocketBase();
      _isCheckingAuth = false;
    } else {
      await _serverStore.saveServers(
        servers: _servers,
        selectedServer: _baseUrl,
      );
    }
    notifyListeners();
  }

  // --- AUTH METHODS ---

  Future<void> ensureE2eeKeysReady() async {
    final user = currentUser;
    if (user == null) return;
    final km = KeyManager(pb: pb, keyNamespace: e2eeKeyNamespace);
    await km.ensureUserKeys(userId: user.id);
  }

  Future<void> login(String identity, String password) async {
    try {
      // Login triggers the onChange listener in CustomSecureAuthStore, which persists the state
      await pb.collection('users').authWithPassword(identity, password);
      await ensureE2eeKeysReady();
    } on ClientException {
      rethrow; 
    }
  }

  Future<void> register({

    required String username,
    required String password,
    required String passwordConfirm,
  }) async {
    final body = <String, dynamic>{
      "username": username,

      "emailVisibility": true,
      "password": password,
      "passwordConfirm": passwordConfirm,
      // PocketBase migration made these fields required (no default).
      "key_version": 1,
      "key_rotated_at": DateTime.now().toUtc().toIso8601String(),
    };
    try {
      await pb.collection('users').create(body: body);
    } on ClientException {
      rethrow;
    }
  }

  Future<void> logout() async {
    // Calling clear() triggers the onChange listener, which clears secure storage
    pb.authStore.clear(); 
  }
}