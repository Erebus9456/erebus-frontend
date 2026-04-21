import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ServerEntry {
  final String url;
  final String nickname;

  const ServerEntry({required this.url, required this.nickname});

  Map<String, dynamic> toJson() => {
        'url': url,
        'nickname': nickname,
      };

  static ServerEntry fromJson(Map<String, dynamic> json) {
    return ServerEntry(
      url: (json['url'] as String?) ?? '',
      nickname: (json['nickname'] as String?) ?? '',
    );
  }
}

class ServerStore {
  static const String defaultServer =
      'http://a2zrowasng3umdxvmv6dz3dwh7u3j36dzvvhyd77jg34qhfdevyxxaad.onion';
  static const String _serversKey = 'pb_servers_list';
  static const String _selectedKey = 'pb_selected_server';

  Future<List<ServerEntry>> loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_serversKey);
    if (raw == null || raw.isEmpty) {
      final entries = <ServerEntry>[
        ServerEntry(url: defaultServer, nickname: defaultNickname(defaultServer)),
      ];
      await prefs.setStringList(
        _serversKey,
        entries.map((e) => jsonEncode(e.toJson())).toList(),
      );
      return entries;
    }

    // Migration: if stored values are plain URLs, convert to JSON entries.
    final entries = <ServerEntry>[];
    bool needsRewrite = false;
    for (final item in raw) {
      final trimmed = item.trim();
      if (trimmed.startsWith('{')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) {
            final entry = ServerEntry.fromJson(decoded);
            if (entry.url.isNotEmpty) {
              entries.add(
                ServerEntry(
                  url: entry.url,
                  nickname: entry.nickname.isNotEmpty
                      ? entry.nickname
                      : defaultNickname(entry.url),
                ),
              );
              continue;
            }
          }
        } catch (_) {
          // fallthrough to legacy handling
        }
      }

      // Legacy URL string
      needsRewrite = true;
      final url = normalizeUrl(trimmed);
      if (url.isNotEmpty) {
        entries.add(ServerEntry(url: url, nickname: defaultNickname(url)));
      }
    }

    final deduped = <String, ServerEntry>{};
    for (final e in entries) {
      deduped[e.url] = e;
    }
    final out = deduped.values.toList();

    if (out.isEmpty) {
      final fallback = ServerEntry(
        url: defaultServer,
        nickname: defaultNickname(defaultServer),
      );
      await prefs.setStringList(_serversKey, <String>[jsonEncode(fallback.toJson())]);
      return <ServerEntry>[fallback];
    }

    if (needsRewrite) {
      await prefs.setStringList(
        _serversKey,
        out.map((e) => jsonEncode(e.toJson())).toList(),
      );
    }

    return out;
  }

  Future<String> loadSelectedServer({required List<ServerEntry> servers}) async {
    final prefs = await SharedPreferences.getInstance();
    final selected = prefs.getString(_selectedKey);
    final urls = servers.map((s) => s.url).toSet();
    if (selected != null && urls.contains(selected)) {
      return selected;
    }
    final fallback = servers.first.url;
    await prefs.setString(_selectedKey, fallback);
    return fallback;
  }

  Future<void> saveServers({
    required List<ServerEntry> servers,
    required String selectedServer,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _serversKey,
      servers.map((e) => jsonEncode(e.toJson())).toList(),
    );
    await prefs.setString(_selectedKey, selectedServer);
  }

  String normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || parsed.scheme.isEmpty) {
      return 'http://$trimmed';
    }
    return trimmed;
  }

  String namespaceForServer(String url) {
    return base64Url.encode(utf8.encode(url)).replaceAll('=', '');
  }

  String defaultNickname(String url) {
    final parsed = Uri.tryParse(url);
    final host = parsed?.host;
    if (host != null && host.isNotEmpty) return host;
    return url;
  }
}

