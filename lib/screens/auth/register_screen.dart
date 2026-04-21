// ignore_for_file: deprecated_member_use, avoid_print


import 'package:flutter/material.dart';
import 'package:erebusv3/classes/themes.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart'; // Required for ClientException
import 'package:erebusv3/classes/auth_provider.dart'; // NEW: AuthProvider import
import 'package:erebusv3/screens/ui/home_screen.dart';
import 'package:erebusv3/screens/auth/server_selector_card.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // NEW: Email controller is required for PocketBase registration
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {

    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // --- PocketBase Registration Logic using Provider ---
  Future<void> _signUp() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false); 

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmController.text.trim();

    // Basic Validation
    if ( username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar("Please fill all fields", isError: true);
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar("Passwords do not match", isError: true);
      return;
    }

    if (password.length < 8) {
      _showSnackBar("Password must be at least 8 characters", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call the register method on the AuthProvider
      await authProvider.register(
        username: username,
        password: password,
        passwordConfirm: confirmPassword,
      );

      // Auto-login after registration, then generate/upload keypairs.
      await authProvider.login(username, password);

      if (!mounted) return;
      _showSnackBar(
        "Account created! You're now logged in.",
        isError: false,
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );

    } on ClientException catch (e) {
      print("PocketBase Registration Error: ${e.response}");
      String errorMessage = "Registration failed. Please check your data.";

      // Attempt to extract specific error from PocketBase response
      if (e.response.containsKey('data')) {
          final errorData = e.response['data'] as Map<String, dynamic>;
          if (errorData.containsKey('email')) {
              errorMessage = "Email is already taken or invalid.";
          } else if (errorData.containsKey('username')) {
              errorMessage = "Username is already taken or invalid.";
          }
      }

      if (mounted) {
        _showSnackBar(errorMessage, isError: true);
      }
    } catch (e) {
      print("General Registration Error: $e");
       if (mounted) {
        _showSnackBar("An unexpected error occurred. Check your connection.", isError: true);
      }
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
    final themeNotifier = context.watch<ThemeNotifier>();
    final currentTheme = themeNotifier.currentTheme;

    return Scaffold(
      backgroundColor: currentTheme.background,
      appBar: AppBar(
        title: Text(
          'Create Account',
          style: TextStyle(color: currentTheme.backgroundText),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: currentTheme.backgroundText),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: currentTheme.background,
          image: DecorationImage(
            image: AssetImage(currentTheme.image),
            fit: BoxFit.fitWidth,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.07),
              BlendMode.darken,
            ),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.person_add_alt_1,
                  size: 80,
                  color: currentTheme.accent,
                ),
                const SizedBox(height: 10),
                Text(
                  "Join Erebus",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: currentTheme.backgroundText,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Welcome to the dark side",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: currentTheme.backgroundText,
                  ),
                ),
                const SizedBox(height: 40),
                const ServerSelectorCard(),
                const SizedBox(height: 16),

          
                
                // Existing Username Input
                _buildTextField(
                  label: "Username",
                  icon: Icons.person,
                  controller: _usernameController,
                  theme: currentTheme,
                  isObscure: false,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: "Password",
                  icon: Icons.lock,
                  controller: _passwordController,
                  theme: currentTheme,
                  isObscure: !_isPasswordVisible,
                  onSuffixPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: "Confirm Password",
                  icon: Icons.lock_outline,
                  controller: _confirmController,
                  theme: currentTheme,
                  isObscure: !_isConfirmVisible,
                  onSuffixPressed: () {
                    setState(() {
                      _isConfirmVisible = !_isConfirmVisible;
                    });
                  },
                ),
                const SizedBox(height: 32),

                // Register Button with Loading State
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentTheme.accent,
                    foregroundColor: currentTheme.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: currentTheme.background))
                      : const Text(
                          "Sign Up",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

                const SizedBox(height: 20),

                // Footer Link
                TextButton(
                  onPressed: () {
                    // Navigate back using pop or replacement
                    Navigator.pop(context);
                  },
                  child: RichText(
                    text: TextSpan(
                      text: "Already have an account? ",
                      style: TextStyle(
                          color: currentTheme.backgroundText.withOpacity(0.7)),
                      children: [
                        TextSpan(
                          text: "Login",
                          style: TextStyle(
                            color: currentTheme.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required AppThemeData theme,
    required bool isObscure,
    VoidCallback? onSuffixPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.receivedBubble.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        style: TextStyle(color: theme.receivedText),
        cursorColor: theme.accent,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: theme.receivedText.withOpacity(0.7)),
          prefixIcon: Icon(icon, color: theme.accent),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: onSuffixPressed != null
              ? IconButton(
                  icon: Icon(
                    isObscure ? Icons.visibility : Icons.visibility_off,
                    color: theme.accent.withOpacity(0.7),
                  ),
                  onPressed: onSuffixPressed,
                )
              : null,
        ),
      ),
    );
  }
}