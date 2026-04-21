// ignore_for_file: avoid_print

import 'package:erebusv3/classes/themes.dart';
import 'package:erebusv3/screens/splash_screen.dart';
import 'package:erebusv3/screens/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

// NEW IMPORTS
import 'package:erebusv3/classes/auth_provider.dart'; 
import 'package:erebusv3/screens/auth/login_screen.dart'; 

const String kThemeKey = 'selectedThemeName';
const String kDefaultThemeName = 'Royal Cipher Dark';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- EXISTING THEME/PREFS LOGIC ---
  final prefs = await SharedPreferences.getInstance();
  String themeName = prefs.getString(kThemeKey) ?? kDefaultThemeName;

  if (prefs.getString(kThemeKey) == null) {
    await prefs.setString(kThemeKey, kDefaultThemeName);
    print('No theme found. Set default theme: $kDefaultThemeName');
  } else {
    print('Loaded theme: $themeName');
  }

  AppThemeData initialTheme = getThemeByName(themeName);
  
  // Use MultiProvider to register both ThemeNotifier and AuthProvider
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeNotifier(initialTheme)),
        // AuthProvider handles PB setup, secure persistence, and session restore
        ChangeNotifierProvider(create: (context) => AuthProvider()), 
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        final currentTheme = themeNotifier.currentTheme;

        return MaterialApp(
          title: 'Erebus',
          debugShowCheckedModeBanner: false,
          theme: currentTheme.toThemeData(),
          
          // Use a Consumer to manage the initial screen based on Auth state
          home: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (authProvider.isCheckingAuth) {
                // Show a loading screen while the session is being restored
                return SplashPage(currentTheme: currentTheme); 
              } else {
                // If checking is done, decide navigation
                return authProvider.isAuthenticated
                    ? const HomeScreen() // Authenticated -> Home
                    : const LoginScreen(); // Not Authenticated -> Login
              }
            },
          ),
        );
      },
    );
  }
}