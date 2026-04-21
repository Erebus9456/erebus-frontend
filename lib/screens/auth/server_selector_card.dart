import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:erebusv3/classes/auth_provider.dart';
import 'package:erebusv3/classes/server_store.dart';
import 'package:erebusv3/classes/themes.dart';

class ServerSelectorCard extends StatelessWidget {
  const ServerSelectorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final appTheme = context.watch<ThemeNotifier>().currentTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appTheme.receivedBubble.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Server',
            style: TextStyle(
              color: appTheme.receivedText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: authProvider.selectedServer,
            items: authProvider.serverEntries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.url,
                    child: Text(
                      entry.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              await context.read<AuthProvider>().setSelectedServer(value);
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showTestServerDialog(context),
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Test Server'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _showManageServersDialog(context),
                icon: const Icon(Icons.dns_outlined),
                label: const Text('Manage Servers'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showManageServersDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => const _ManageServersDialog(),
    );
  }

  Future<void> _showTestServerDialog(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final server = authProvider.selectedServer;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TestServerDialog(serverUrl: server),
    );
  }
}

class _TestServerDialog extends StatefulWidget {
  final String serverUrl;

  const _TestServerDialog({required this.serverUrl});

  @override
  State<_TestServerDialog> createState() => _TestServerDialogState();
}

class _TestServerDialogState extends State<_TestServerDialog> {
  _TestStatus _torStatus = _TestStatus.pending;
  _TestStatus _pbStatus = _TestStatus.pending;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    try {
      if (!mounted) return;
      setState(() {
        _torStatus = _TestStatus.running;
        _pbStatus = _TestStatus.pending;
        _error = null;
      });

      final torOk = await _testTor();
      if (!mounted) return;
      setState(() {
        _torStatus = torOk ? _TestStatus.passed : _TestStatus.failed;
      });

      if (!torOk) {
        setState(() {
          _pbStatus = _TestStatus.skipped;
          _error =
              'Test 1/2 failed. Tor may not be connected.\n\nPlease check if Tor is connected to the app, then try again.';
        });
        return;
      }

      setState(() {
        _pbStatus = _TestStatus.running;
      });

      final pbResult = await _testPocketBaseHealth(widget.serverUrl);
      if (!mounted) return;
      setState(() {
        _pbStatus = pbResult.ok ? _TestStatus.passed : _TestStatus.failed;
        _error = pbResult.ok ? null : pbResult.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _torStatus = _torStatus == _TestStatus.running
            ? _TestStatus.failed
            : _torStatus;
        _pbStatus = _pbStatus == _TestStatus.running
            ? _TestStatus.failed
            : _pbStatus;
        _error = 'Test failed: $e';
      });
    }
  }

  Future<bool> _testTor() async {
    final uri = Uri.parse('https://check.torproject.org/');
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    debugPrint('[TorTest] GET $uri -> ${resp.statusCode}');
    debugPrint('[TorTest] body_snippet="${_snippet(resp.body)}"');
    if (resp.statusCode != 200) return false;
    return resp.body.contains(
      'Congratulations. This browser is configured to use Tor.',
    );
  }

  Future<_PocketBaseHealthResult> _testPocketBaseHealth(String baseUrl) async {
    final uri = Uri.parse('$baseUrl/api/health');
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    debugPrint('[PocketBaseTest] GET $uri -> ${resp.statusCode}');
    debugPrint('[PocketBaseTest] body_snippet="${_snippet(resp.body)}"');

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return _PocketBaseHealthResult(
        ok: false,
        message:
            'Server is down (HTTP ${resp.statusCode}).\n\nContact the server admins to verify the Erebus server.',
      );
    }

    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        final code = decoded['code'];
        final message = decoded['message'];
        if (code == 200 && message == 'API is healthy.') {
          return const _PocketBaseHealthResult(ok: true);
        }
        if (message is String && message.trim().isNotEmpty) {
          return _PocketBaseHealthResult(ok: false, message: message);
        }
      }
    } catch (_) {
      // Fall through to raw body.
    }

    return _PocketBaseHealthResult(
      ok: false,
      message: resp.body.trim().isEmpty ? 'Unknown server error.' : resp.body,
    );
  }

  String _snippet(String s, {int max = 300}) {
    final oneLine = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.length <= max) return oneLine;
    return '${oneLine.substring(0, max)}...';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Test Server'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Server: ${widget.serverUrl}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          _TestRow(
            label: 'Test 1/2: Tor connection',
            status: _torStatus,
            successText: 'Test 1/2 passed (Tor is working)',
            failText: 'Test 1/2 failed (check Tor connection)',
            skippedText: 'Skipped',
          ),
          const SizedBox(height: 8),
          _TestRow(
            label: 'Test 2/2: PocketBase health',
            status: _pbStatus,
            successText: 'Test 2/2 passed (server is alive)',
            failText: 'Test 2/2 failed (server error)',
            skippedText: 'Skipped',
          ),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!)],
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              (_torStatus == _TestStatus.running ||
                  _pbStatus == _TestStatus.running)
              ? null
              : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

enum _TestStatus { pending, running, passed, failed, skipped }

class _PocketBaseHealthResult {
  final bool ok;
  final String? message;

  const _PocketBaseHealthResult({required this.ok, this.message});
}

class _TestRow extends StatelessWidget {
  final String label;
  final _TestStatus status;
  final String successText;
  final String failText;
  final String skippedText;

  const _TestRow({
    required this.label,
    required this.status,
    required this.successText,
    required this.failText,
    required this.skippedText,
  });

  @override
  Widget build(BuildContext context) {
    Widget trailing;
    String subtitle;

    if (status == _TestStatus.running) {
      trailing = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
      subtitle = 'Running...';
    } else if (status == _TestStatus.passed) {
      trailing = const Icon(Icons.check_circle, color: Colors.green);
      subtitle = successText;
    } else if (status == _TestStatus.failed) {
      trailing = const Icon(Icons.cancel, color: Colors.red);
      subtitle = failText;
    } else if (status == _TestStatus.skipped) {
      trailing = const Icon(Icons.remove_circle_outline, color: Colors.grey);
      subtitle = skippedText;
    } else {
      trailing = const Icon(Icons.more_horiz);
      subtitle = 'Pending...';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}

class _ManageServersDialog extends StatelessWidget {
  const _ManageServersDialog();

  Future<void> _addServer(BuildContext context) async {
    final urlController = TextEditingController();
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nickname (optional)',
                hintText: 'My onion server',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://example.onion',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, urlController.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await context.read<AuthProvider>().addServer(
            result,
            nickname: nameController.text.trim(),
          );
    }
  }

  Future<void> _editServer(BuildContext context, String oldUrl) async {
    final auth = context.read<AuthProvider>();
    final entry = auth.serverEntries.firstWhere(
      (e) => e.url == oldUrl,
      orElse: () => ServerEntry(url: oldUrl, nickname: oldUrl),
    );
    final urlController = TextEditingController(text: entry.url);
    final nameController = TextEditingController(text: entry.nickname);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nickname'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'Server URL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, urlController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await context.read<AuthProvider>().updateServer(
        oldUrl: oldUrl,
        newUrl: result,
        nickname: nameController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final servers = authProvider.serverEntries;
    final selected = authProvider.selectedServer;

    return AlertDialog(
      title: const Text('Manage Servers'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: servers.length,
          itemBuilder: (ctx, index) {
            final server = servers[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                server.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                server.url == selected ? '${server.url} (Selected)' : server.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _editServer(context, server.url),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: servers.length <= 1
                        ? null
                        : () =>
                              context.read<AuthProvider>().removeServer(server.url),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _addServer(context),
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
