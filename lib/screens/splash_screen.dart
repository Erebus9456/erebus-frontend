import 'package:erebusv3/classes/themes.dart';
import 'package:flutter/material.dart';
import 'package:easy_splash_screen/easy_splash_screen.dart'; // Assuming you have this package

class SplashPage extends StatelessWidget {
  // Requires the current theme data from the main widget for styling
  final AppThemeData currentTheme;

  const SplashPage({super.key, required this.currentTheme});

  @override
  Widget build(BuildContext context) {


    return EasySplashScreen(
      // Use the theme's logo asset path
      logo: Image.asset(currentTheme.image),
      title: Text(
        "Erebus",
        style: TextStyle(
          fontSize: 24, 
          fontWeight: FontWeight.bold,
          color:  currentTheme.backgroundText, // Use the theme's text color
        ),
      ),
      // Use the theme's background color
      backgroundColor: currentTheme.background,
      showLoader: true,
      loaderColor:  currentTheme.backgroundText,
      loadingText: Text(
        "Loading the darkness...",
        style: TextStyle(color:  currentTheme.backgroundText), // Use the theme's text color
      ),
      // navigator: const LoginScreen(),
      durationInSeconds: 3, // Reduced duration for faster testing
    );
  }
}