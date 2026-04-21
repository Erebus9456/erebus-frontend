// ignore_for_file: deprecated_member_use, avoid_print

import 'package:erebusv3/screens/auth/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:erebusv3/classes/themes.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart'; // Required for ClientException
import 'package:erebusv3/classes/auth_provider.dart'; // NEW: AuthProvider import
import 'package:erebusv3/screens/auth/server_selector_card.dart';

// NOTE: The HomeScreen placeholder is removed from this file.

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  // --- PocketBase Authentication Logic using Provider ---
  Future<void> _login() async {
    // Do not listen: false is correct here as we are only calling a method
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final identity = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (identity.isEmpty || password.isEmpty) {
      _showSnackBar(
        "Please enter both username/email and password",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call the login method on the AuthProvider
      // Success will trigger AuthProvider's notifyListeners() and MyApp's navigation
      await authProvider.login(identity, password);

      if (!mounted) return;
      // Get the username from the newly authenticated user model
      _showSnackBar(
        "Welcome back, ${authProvider.currentUser!.getStringValue('username')}!",
      );
    } on ClientException catch (e) {
      print("PocketBase Login Error: ${e.response}");
      const String errorMessage = "Login failed. Invalid username or password.";
      if (mounted) {
        _showSnackBar(errorMessage, isError: true);
      }
    } catch (e) {
      print("General Login Error: $e");
      if (mounted) {
        _showSnackBar(
          "An unexpected error occurred. Check your connection.",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Helper methods kept from your original file
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: isError ? Colors.white : Colors.black),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
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
          ),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
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

  @override
  Widget build(BuildContext context) {
    // Access Theme Data
    final themeNotifier = context.watch<ThemeNotifier>();
    final currentTheme = themeNotifier.currentTheme;

    return Scaffold(
      backgroundColor: currentTheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Welcome Back',
          style: TextStyle(color: currentTheme.backgroundText),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: currentTheme.backgroundText),
      ),
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
                  Icons.account_circle,
                  size: 80,
                  color: currentTheme.accent,
                ),
                const SizedBox(height: 10),
                Text(
                  "Login",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: currentTheme.backgroundText,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Sign in to continue your conversations",
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

                // Inputs
                _buildTextField(
                  label:
                      "Username/Email", // Note: PocketBase uses "identity" for either
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

                // Align(
                //   alignment: Alignment.centerRight,
                //   child: TextButton(
                //     onPressed: () {
                //       _showSnackBar("Forgot Password clicked! (UI only)");
                //     },
                //     child: Text(
                //       "Forgot Password?",
                //       style: TextStyle(
                //         color: currentTheme.backgroundText.withOpacity(0.8),
                //         fontWeight: FontWeight.w600,
                //       ),
                //     ),
                //   ),
                // ),
                const SizedBox(height: 24),

                // Login Button with Loading State
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentTheme.accent,
                    foregroundColor: currentTheme.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                    shadowColor: Colors.black.withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: currentTheme.background,
                          ),
                        )
                      : const Text(
                          "Log In",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

                const SizedBox(height: 30),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: currentTheme.backgroundText),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Use push to keep LoginScreen available
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        "Sign Up",
                        style: TextStyle(
                          color: currentTheme.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
