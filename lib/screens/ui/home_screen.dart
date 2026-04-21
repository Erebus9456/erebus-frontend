import 'package:erebusv3/screens/ui/chat_screen.dart';
import 'package:erebusv3/screens/theme_preview_screen.dart';
import 'package:erebusv3/screens/ui/group_creation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:erebusv3/classes/auth_provider.dart';
import 'package:erebusv3/classes/themes.dart';
import 'package:erebusv3/screens/profile_screen.dart';

import 'package:flutter/foundation.dart';
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- New State for Backend Data ---
  List<RecordModel> _chats = [];
  bool _isLoading = true;
  bool _isError = false;
  late dynamic _chatSubscription;

  // --- Search State ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchChats();
    _subscribeToChatUpdates();
  }

  @override
  void dispose() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.pb.realtime.unsubscribe('chats');
    _searchController.dispose();
    super.dispose();
  }

  // --- PocketBase Logic: Fetch Chats ---
  Future<void> _fetchChats() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;

    if (currentUserId == null) {
      setState(() {
        _isLoading = false;
        _isError = true;
      });
      return;
    }

    try {
      final result = await authProvider.pb
          .collection('chats')
          .getList(
            filter: 'members ~ "$currentUserId"',
            expand: 'members',
            sort: '-last_message,-updated',
          );

      print('--- DEBUG FETCH: Retrieved ${result.items.length} chats. ---');

      if (mounted) {
        setState(() {
          _chats = result.items;
          _isLoading = false;
          _isError = false;
        });
        debugPrint(
          '--- DEBUG FETCH: Set state with ${_chats.length} chats ---',
        );
      }
    } on ClientException catch (e) {
      _showSnackBar(
        'Unable to connect to PocketBase. Please check if Tor is connected to the app, otherwise contact the server admin to verify if server is alive.',
        isError: true,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
        });
      }
    }
  }

  // *** FIX: Safe access for e.data to resolve 'containsKey' error ***
  void _subscribeToChatUpdates() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    const collectionName = 'chats';
    final currentUserId = authProvider.currentUser?.id;
    print('Current user ID in subscription: $currentUserId');

    debugPrint('Subscribing to chat updates for user: $currentUserId');

    authProvider.pb.realtime.subscribe(collectionName, (e) {
      try {
        print('Received realtime event for chats: ${e.data}');
        // Handle if e.data is String (raw JSON) or Map
        Map<String, dynamic> dataMap;
        if (e.data is String) {
          dataMap = jsonDecode(e.data) as Map<String, dynamic>;
        } else if (e.data is Map) {
          dataMap = e.data as Map<String, dynamic>;
        } else {
          print('e.data is neither String nor Map');
          return;
        }
        print('DataMap keys: ${dataMap.keys}');

        print(
          'Has action: ${dataMap.containsKey('action')}, Has record: ${dataMap.containsKey('record')}',
        );

        if (dataMap.containsKey('action') && dataMap.containsKey('record')) {
          final action = dataMap['action'] as String;
          final record = dataMap['record'] as Map<String, dynamic>;

          print('Processing $action for chat: ${record['id']}');
          print(
            'Action: $action, Record ID: ${record['id']}, Members: ${record['members']}, Current: $currentUserId',
          );

          if (action == 'create' || action == 'update') {
            final members = record['members'] as List<dynamic>? ?? [];
            print('Members: $members, Current user: $currentUserId');
            if (members.contains(currentUserId)) {
              print('User is member, refetching chats');
              // This chat involves the current user, refetch to update the list
              _fetchChats();
            } else {
              print('User is not member, ignoring');
            }
          } else if (action == 'delete') {
            // If a chat was deleted, refetch to remove it from the list
            print('Chat deleted, refetching');
            _fetchChats();
          }
        } else {
          print('DataMap does not contain action or record keys');
        }
      } catch (error) {
        print('Error in realtime callback: $error');
      }
    });
  }
  // *************************************************************

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await Provider.of<AuthProvider>(context, listen: false).logout();
    }
  }

  String _getDrawerAvatarUrl(
    AuthProvider authProvider,
    RecordModel? currentUser,
  ) {
    if (currentUser == null) return '';

    final avatarFileName = currentUser.getStringValue('avatar', '');

    if (avatarFileName.isEmpty) return '';

    final baseUrl = authProvider.pb.baseUrl;
    const collectionName = 'users';
    final recordId = currentUser.id;

    return '$baseUrl/api/files/$collectionName/$recordId/$avatarFileName';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'busy':
      case 'Busy':
        return Colors.red;
      case 'away':
      case 'Away':
        return Colors.amber;
      case 'offline':
      default:
        return Colors.grey;
    }
  }

  RecordModel? _getOtherMember(RecordModel chat, String currentUserId) {
    final expandedMembers = chat.get<List<RecordModel>>('expand.members');

    if (expandedMembers.isEmpty) {
      return null;
    }

    final otherMembers = expandedMembers
        .where((member) => member.id != currentUserId)
        .toList();

    if (otherMembers.isEmpty) {
      return null;
    }

    return otherMembers.first;
  }

  String _getChatTitle(RecordModel chat, String currentUserId) {
    String title = '';

    if (chat.getStringValue('type', '') == 'group') {
      title = chat.getStringValue('title', '');
      if (title.isNotEmpty) return title;
      return 'Group Chat';
    }

    final otherMember = _getOtherMember(chat, currentUserId);
    if (otherMember != null) {
      title = otherMember.getStringValue('username', '');
      if (title.isNotEmpty) {
        return title;
      }

      title = otherMember.getStringValue('name', '');
      if (title.isNotEmpty) {
        return title;
      }

      return otherMember.id;
    }

    return 'DATA ERROR: Missing Partner Record';
  }

  void _openChat(BuildContext context, RecordModel chatRecord) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(chat: chatRecord)),
    );
  }

  void _showNewConversationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return const AlertDialog(
          title: Text('Start New Conversation'),
          content: SizedBox(
            width: double.maxFinite,
            child: _UserSearchWidget(),
          ),
          actions: <Widget>[],
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
  }

  String _formatTimestamp(BuildContext context, DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    const List<String> shortWeekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];

    if (difference.inDays == 0) {
      return TimeOfDay.fromDateTime(timestamp).format(context);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      final index = timestamp.weekday - 1;
      return shortWeekdays[index];
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year.toString().substring(2)}';
    }
  }

  // --- Search Logic ---
  List<RecordModel> _getFilteredChats(String currentUserId) {
    if (_searchQuery.isEmpty) {
      return _chats;
    }

    final query = _searchQuery.toLowerCase();
    return _chats.where((chat) {
      final chatTitle = _getChatTitle(chat, currentUserId).toLowerCase();

      // Search by chat title
      if (chatTitle.contains(query)) {
        return true;
      }

      // Search by member names
      final expandedMembers = chat.get<List<RecordModel>>('expand.members');
      for (var member in expandedMembers) {
        final username = member.getStringValue('username', '').toLowerCase();
        final name = member.getStringValue('name', '').toLowerCase();
        if (username.contains(query) || name.contains(query)) {
          return true;
        }
      }

      return false;
    }).toList();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // --- UI Helpers ---
  Widget _buildSearchAnchor(AppThemeData appTheme) {
    return SearchAnchor(
      isFullScreen: false,
      viewHintText: 'Search chats and members...',
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          controller: controller,
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: 16.0),
          ),
          onChanged: (_) {
            setState(() {
              _searchQuery = controller.text;
            });
          },
          leading: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.search),
          ),
          trailing: controller.text.isNotEmpty
              ? [
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                ]
              : [],
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController controller) {
        final currentUserId = Provider.of<AuthProvider>(
          context,
          listen: false,
        ).currentUser?.id;
        if (currentUserId == null) return [];
        return _getFilteredChats(currentUserId).take(10).map((chat) {
          final title = _getChatTitle(chat, currentUserId);
          return ListTile(
            title: Text(title),
            onTap: () {
              _openChat(context, chat);
              controller.closeView(title);
            },
          );
        }).toList();
      },
    );
  }

  Widget _buildChatList(AppThemeData appTheme, String currentUserId) {
    final filteredChats = _getFilteredChats(currentUserId);
    final baseUrl = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).pb.baseUrl;

    if (filteredChats.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _searchQuery.isEmpty
                        ? 'No conversations found.'
                        : 'No results for "$_searchQuery"',
                    style: TextStyle(color: appTheme.backgroundText),
                  ),
                  if (_searchQuery.isEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showNewConversationDialog,
                      icon: Icon(Icons.add, color: appTheme.accent),
                      label: Text(
                        'Start New Chat',
                        style: TextStyle(color: appTheme.accent),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: filteredChats.length,
      itemBuilder: (context, index) {
        final chat = filteredChats[index];
        final chatTitle = _getChatTitle(chat, currentUserId);
        final isGroup = chat.getStringValue('type', '') == 'group';
        final memberCount = isGroup
            ? (chat.getListValue('members')?.length ?? 0)
            : 0;
        final lastMessageContent = isGroup
            ? 'Members: $memberCount'
            : 'Tap to start a conversation...';
        final lastMessageTime = DateTime.parse(chat.updated);
        const unreadCount = 0;

        final otherMember = _getOtherMember(chat, currentUserId);
        final avatarFileName = otherMember?.getStringValue('avatar', '');
        final otherMemberId = otherMember?.id;

        final otherMemberAvatarUrl =
            (avatarFileName != null &&
                otherMemberId != null &&
                avatarFileName!.isNotEmpty)
            ? '$baseUrl/api/files/users/$otherMemberId/$avatarFileName'
            : '';

        final avatarInitial =
            (chatTitle.trim().isNotEmpty ? chatTitle.trim()[0] : 'U')
                .toUpperCase();

        return Semantics(
          label: 'Chat with $chatTitle',
          button: true,
          enabled: true,
          child: ListTile(
            onTap: () => _openChat(context, chat),
            leading: Semantics(
              label: 'Avatar for $chatTitle',
              image: true,
              child: CircleAvatar(
                radius: 28,
                backgroundColor: appTheme.accent,
                backgroundImage: otherMemberAvatarUrl.isNotEmpty
                    ? NetworkImage(otherMemberAvatarUrl)
                    : null,
                child: otherMemberAvatarUrl.isNotEmpty
                    ? null
                    : Text(
                        avatarInitial,
                        style: TextStyle(
                          color: appTheme.backgroundText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            title: Text(
              chatTitle,
              style: TextStyle(
                color: appTheme.backgroundText,
                fontWeight: FontWeight.w600,
              ),
              semanticsLabel: 'Chat title: $chatTitle',
            ),
            subtitle: Text(
              lastMessageContent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: appTheme.backgroundText.withOpacity(0.6)),
              semanticsLabel: 'Last message: $lastMessageContent',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTimestamp(context, lastMessageTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: appTheme.backgroundText.withOpacity(0.6),
                    fontWeight: unreadCount > 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                if (unreadCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: appTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : unreadCount.toString(),
                        style: TextStyle(
                          color: appTheme.background,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final appTheme = context.watch<ThemeNotifier>().currentTheme;
    final RecordModel? currentUser = authProvider.currentUser;

    final username =
        currentUser?.getStringValue('username', 'Guest') ?? 'Guest';
    final email = currentUser?.getStringValue('email', 'N/A') ?? 'N/A';
    final status =
        currentUser?.getStringValue('status', 'offline') ?? 'offline';
    final currentUserId = currentUser?.id;

    if (currentUser == null || currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final baseUrl = authProvider.pb.baseUrl;
    final drawerAvatarUrl = _getDrawerAvatarUrl(authProvider, currentUser);

    return Scaffold(
      appBar: AppBar(
        title: _buildSearchAnchor(appTheme),
        backgroundColor: appTheme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: appTheme.backgroundText),
        actions: [
          IconButton(
            icon: Icon(Icons.group_add, color: appTheme.backgroundText),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return GroupCreationDialog(onGroupCreated: _fetchChats);
                },
              );
            },
          ),
        ],
      ),

      drawer: Drawer(
        backgroundColor: appTheme.background,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(
                username,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: appTheme.backgroundText,
                ),
              ),
              accountEmail: Text(
                email,
                style: TextStyle(
                  color: appTheme.backgroundText.withOpacity(0.7),
                ),
              ),
              currentAccountPicture: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: appTheme.accent,
                    key: ValueKey(drawerAvatarUrl),
                    child: drawerAvatarUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              drawerAvatarUrl,
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 40,
                            color: appTheme.background,
                          ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: appTheme.background,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              decoration: BoxDecoration(color: appTheme.accent),
            ),

            ListTile(
              leading: Icon(Icons.account_circle, color: appTheme.accent),
              title: Text(
                'Edit Profile',
                style: TextStyle(color: appTheme.backgroundText),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),

            ListTile(
              leading: Icon(Icons.dashboard, color: appTheme.accent),
              title: Text(
                'Dashboard',
                style: TextStyle(color: appTheme.backgroundText),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            Divider(color: appTheme.accent.withOpacity(0.3)),

            ExpansionTile(
              leading: Icon(Icons.settings, color: appTheme.accent),
              title: Text(
                'Settings',
                style: TextStyle(color: appTheme.backgroundText),
              ),
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    'Logout',
                    style: TextStyle(color: appTheme.backgroundText),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _handleLogout(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.dark_mode, color: appTheme.accent),
                  title: Text(
                    'Toggle Theme',
                    style: TextStyle(color: appTheme.backgroundText),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ThemeSelector(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchChats,
              child: _isError
                  ? CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Unable to connect. Please check if Tor is connected to the app, otherwise contact the server admin to verify if the server is alive.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: _fetchChats,
                                  icon: Icon(
                                    Icons.refresh,
                                    color: appTheme.accent,
                                  ),
                                  label: Text(
                                    'Try Again',
                                    style: TextStyle(color: appTheme.accent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : _buildChatList(appTheme, currentUserId!),
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showNewConversationDialog,
        backgroundColor: appTheme.accent,
        child: Icon(Icons.add_comment, color: appTheme.background),
      ),
    );
  }
}

// REFACTORED WIDGET FOR EXACT USER SEARCH AND CHAT CREATION

class _UserSearchWidget extends StatefulWidget {
  const _UserSearchWidget();

  @override
  State<_UserSearchWidget> createState() => _UserSearchWidgetState();
}

class _UserSearchWidgetState extends State<_UserSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  RecordModel? _foundUser;
  bool _isSearching = false;
  String? _message;

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
    _searchController.dispose();
    super.dispose();
  }

  // --- PocketBase Logic: Search for Exact User Match ---
  Future<void> _searchUser() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _foundUser = null;
        _message = 'Please enter a username.';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _foundUser = null;
      _message = null;
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
        setState(() {
          _foundUser = result.items.first;
          _message = null;
        });
      } else {
        setState(() {
          _foundUser = null;
          _message = 'No user found with the exact username: "$query".';
        });
      }
    } on ClientException catch (e) {
      _showSnackBar(
        'Search failed: ${e.response['message'] ?? 'Network error.'}',
        isError: true,
      );
      setState(() => _message = 'Error searching for user.');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // --- PocketBase Logic: Create Private Chat ---
  Future<void> _createPrivateChat(RecordModel friendUser) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser!.id;
    final friendId = friendUser.id;

    final friendUsername = friendUser.getStringValue(
      'username',
      'Unknown User',
    );

    setState(() => _isSearching = true);

    try {
      // 1. Check if a private chat already exists
      final existingChats = await authProvider.pb
          .collection('chats')
          .getList(
            filter:
                'type = "private" && members ~ "$currentUserId" && members ~ "$friendId"',
          );

      if (existingChats.items.isNotEmpty) {
        _showSnackBar(
          'Chat with $friendUsername already exists!',
          isError: false,
        );
        Navigator.pop(context); // Close dialog
      } else {
        // 2. Create a new private chat record
        final chatData = {
          'type': 'private',
          'members': [currentUserId, friendId],
        };

        print(
          '--- DEBUG CREATE: Sending chat creation data to PocketBase: $chatData ---',
        );

        await authProvider.pb.collection('chats').create(body: chatData);
        _showSnackBar(
          'Started new chat with $friendUsername successfully!',
          isError: false,
        );
        Navigator.pop(context); // Close dialog
      }
    } on ClientException catch (e) {
      _showSnackBar(
        'Chat creation failed: ${e.response['message'] ?? 'Validation error.'}',
        isError: true,
      );
    } catch (e) {
      _showSnackBar('An unexpected error occurred.', isError: true);
    } finally {
      setState(() => _isSearching = false);
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Enter exact username...',
            border: const OutlineInputBorder(),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchUser,
                  ),
          ),
          onSubmitted: (value) => _searchUser(),
        ),

        const SizedBox(height: 16),

        if (_isSearching && _foundUser == null)
          const Center(child: Text('Searching...'))
        else if (_message != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                _message!,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          )
        else if (_foundUser != null)
          _buildFoundUserTile(authProvider, _foundUser!)
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                'Enter a username above and press search.',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
      ],
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
          backgroundImage: avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('@${user.getStringValue('username', '')}'),
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: const Text('Start Chat'),
          onPressed: _isSearching ? null : () => _createPrivateChat(user),
        ),
      ),
    );
  }
}
