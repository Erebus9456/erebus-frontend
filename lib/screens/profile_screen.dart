import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:erebusv3/classes/auth_provider.dart';
import 'package:http/http.dart' as http; // Required for MultipartFile

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  File? _newAvatarFile;
  String? _selectedStatus;
  bool _isLoading = false;

  final List<String> _statusOptions = ['online', 'offline', 'away', 'busy'];

  @override
  void initState() {
    super.initState();
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (currentUser != null) {
      // Use positional argument for default value
      _nameController.text = currentUser.getStringValue('name', '');
      _bioController.text = currentUser.getStringValue('bio', '');
      
      final currentStatus = currentUser.getStringValue('status', 'offline');
      if (_statusOptions.contains(currentStatus)) {
        _selectedStatus = currentStatus;
      } else {
        _selectedStatus = 'offline';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
  
  // --- PocketBase Helper Methods ---
  
  String _getAvatarUrl(RecordModel user) {
    final avatarFileName = user.getStringValue('avatar', '');
    if (avatarFileName.isEmpty) return '';
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.pb.getFileUrl(user, avatarFileName).toString();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _newAvatarFile = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      _showSnackBar('Error: User not authenticated.', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    try {
      final String userId = currentUser.id;
      
      // 1. Prepare data 
      final body = <String, dynamic>{
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'status': _selectedStatus,
      };

      // 2. Prepare files for upload
      List<http.MultipartFile> files = [];
      if (_newAvatarFile != null) {
        // Use http.MultipartFile.fromPath for asynchronous file reading
        files.add(
          await http.MultipartFile.fromPath(
            'avatar', // Field name in your DB schema
            _newAvatarFile!.path,
            filename: _newAvatarFile!.path.split('/').last,
          ),
        );
      }
      
      // 3. Send the update request
      await authProvider.pb.collection('users').update(
        userId,
        body: body,
        files: files,
      );

      if (mounted) {
        _showSnackBar('Profile updated successfully!', isError: false);
        setState(() {
          _newAvatarFile = null; 
        });
      }

    } on ClientException catch (e) {
       _showSnackBar('Update failed: ${e.response['message'] ?? 'Network or validation error.'}', isError: true);
    } catch (e) {
      _showSnackBar('An unexpected error occurred.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("User not logged in.")));
    }

    final avatarUrl = _getAvatarUrl(currentUser);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _saveProfile,
            icon: _isLoading 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // --- Profile Picture Section ---
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Theme.of(context).secondaryHeaderColor,
                  backgroundImage: _newAvatarFile != null
                      ? FileImage(_newAvatarFile!) as ImageProvider
                      : avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                  child: _newAvatarFile == null && avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 60)
                      : null,
                ),
              ),
              TextButton(
                onPressed: _pickImage,
                child: const Text("Change Profile Picture"),
              ),
              const SizedBox(height: 20),

              // --- Display Name ---
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Display name cannot be empty.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- Status Dropdown ---
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.traffic),
                ),
                value: _selectedStatus,
                items: _statusOptions.map((String status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status.toUpperCase()),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedStatus = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a status.' : null,
              ),
              const SizedBox(height: 20),

              // --- Bio (Rich Text Editor equivalent) ---
              TextFormField(
                controller: _bioController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Tell us about yourself...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}