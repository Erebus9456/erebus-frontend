import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:erebusv3/classes/auth_provider.dart';
import 'package:erebusv3/classes/themes.dart';

class GroupCreationDialog extends StatefulWidget {
  final VoidCallback? onGroupCreated;

  const GroupCreationDialog({super.key, this.onGroupCreated});

  @override
  State<GroupCreationDialog> createState() => _GroupCreationDialogState();
}

class _GroupCreationDialogState extends State<GroupCreationDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<RecordModel> _selectedUsers = [];
  RecordModel? _foundUser;
  bool _isSearching = false;
  String? _searchMessage;
  bool _isCreating = false;

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Search for a user to add to the group
  Future<void> _searchUser() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _foundUser = null;
        _searchMessage = 'Please enter a username.';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _foundUser = null;
      _searchMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final filter = 'username = "$query" && id != "$currentUserId"';

      final result = await authProvider.pb
          .collection('users')
          .getList(
            filter: filter,
            fields: 'id, username, name, avatar, status',
          );

      if (result.items.isNotEmpty) {
        final user = result.items.first;
        if (_selectedUsers.any((u) => u.id == user.id)) {
          setState(() {
            _foundUser = null;
            _searchMessage = 'User already added to the group.';
          });
        } else {
          setState(() {
            _foundUser = user;
            _searchMessage = null;
          });
        }
      } else {
        setState(() {
          _foundUser = null;
          _searchMessage = 'No user found with the exact username: "$query".';
        });
      }
    } on ClientException catch (e) {
      _showSnackBar(
        'Search failed: ${e.response['message'] ?? 'Network error.'}',
        isError: true,
      );
      setState(() => _searchMessage = 'Error searching for user.');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _addUserToGroup(RecordModel user) {
    setState(() {
      _selectedUsers.add(user);
      _foundUser = null;
      _searchController.clear();
      _searchMessage = null;
    });
  }

  void _removeUserFromGroup(RecordModel user) {
    setState(() {
      _selectedUsers.removeWhere((u) => u.id == user.id);
    });
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      _showSnackBar('Please enter a group name.', isError: true);
      return;
    }
    if (_selectedUsers.length < 2) {
      _showSnackBar('Please add at least 2 members.', isError: true);
      return;
    }

    setState(() => _isCreating = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser!.id;
    final memberIds = [currentUserId, ..._selectedUsers.map((u) => u.id)];

    try {
      // Check if a group with the same name already exists
      final existingGroups = await authProvider.pb
          .collection('chats')
          .getList(
            filter: 'type = "group" && title = "$groupName"',
          );

      if (existingGroups.items.isNotEmpty) {
        _showSnackBar('A group with this name already exists!', isError: true);
        return;
      }

      // Create the group chat
      final chatData = {
        'type': 'group',
        'title': groupName,
        'members': memberIds,
      };

      await authProvider.pb.collection('chats').create(body: chatData);
      _showSnackBar('Group "$groupName" created successfully!', isError: false);
      widget.onGroupCreated?.call();
      Navigator.pop(context); // Close dialog
    } on ClientException catch (e) {
      _showSnackBar(
        'Group creation failed: ${e.response['message'] ?? 'Validation error.'}',
        isError: true,
      );
    } catch (e) {
      _showSnackBar('An unexpected error occurred.', isError: true);
    } finally {
      setState(() => _isCreating = false);
    }
  }

  String _getAvatarUrl(AuthProvider authProvider, RecordModel user) {
    final avatarFileName = user.getStringValue('avatar', '');
    if (avatarFileName.isEmpty) return '';

    final baseUrl = authProvider.pb.baseUrl;
    const collectionName = 'users';
    final recordId = user.id;

    return '$baseUrl/api/files/$collectionName/$recordId/$avatarFileName';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final appTheme = context.watch<ThemeNotifier>().currentTheme;

    return AlertDialog(
      backgroundColor: appTheme.background,
      title: Text('Create New Group', style: TextStyle(color: appTheme.backgroundText)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Group Name Field
              TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  labelStyle: TextStyle(color: appTheme.backgroundText),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: appTheme.backgroundText.withOpacity(0.5)),
                  ),
                ),
                style: TextStyle(color: appTheme.backgroundText),
                maxLength: 50,
              ),
              const SizedBox(height: 16),

              // Selected Members List
              if (_selectedUsers.isNotEmpty) ...[
                Text('Selected Members (${_selectedUsers.length})', style: TextStyle(color: appTheme.backgroundText)),
                const SizedBox(height: 8),
                ..._selectedUsers.map((user) => _buildSelectedUserTile(authProvider, user)),
                const SizedBox(height: 16),
              ],

              // User Search Section
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search username to add...',
                  hintStyle: TextStyle(color: appTheme.backgroundText.withOpacity(0.5)),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: appTheme.backgroundText.withOpacity(0.5)),
                  ),
                  suffixIcon: _isSearching
                      ? Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: appTheme.backgroundText),
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.search, color: appTheme.backgroundText),
                          onPressed: _searchUser,
                        ),
                ),
                style: TextStyle(color: appTheme.backgroundText),
                onSubmitted: (value) => _searchUser(),
              ),

              const SizedBox(height: 8),

              if (_isSearching && _foundUser == null)
                Center(child: Text('Searching...', style: TextStyle(color: appTheme.backgroundText)))
              else if (_searchMessage != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      _searchMessage!,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else if (_foundUser != null)
                _buildFoundUserTile(authProvider, _foundUser!)
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Search for users to add to the group.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: appTheme.backgroundText)),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createGroup,
          style: ElevatedButton.styleFrom(
            backgroundColor: appTheme.accent,
            foregroundColor: appTheme.backgroundText,
          ),
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Group'),
        ),
      ],
    );
  }

  Widget _buildSelectedUserTile(AuthProvider authProvider, RecordModel user) {
    final avatarUrl = _getAvatarUrl(authProvider, user);
    final displayName = user.getStringValue(
      'name',
      user.getStringValue('username', 'User'),
    );

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        leading: CircleAvatar(
          radius: 20,
          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 20) : null,
        ),
        title: Text(displayName, style: const TextStyle(fontSize: 14)),
        subtitle: Text('@${user.getStringValue('username', '')}', style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
          onPressed: () => _removeUserFromGroup(user),
        ),
      ),
    );
  }

  Widget _buildFoundUserTile(AuthProvider authProvider, RecordModel user) {
    final avatarUrl = _getAvatarUrl(authProvider, user);
    final displayName = user.getStringValue(
      'name',
      user.getStringValue('username', 'User'),
    );

    return Card(
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          child: avatarUrl.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('@${user.getStringValue('username', '')}'),
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
          onPressed: () => _addUserToGroup(user),
        ),
      ),
    );
  }
}