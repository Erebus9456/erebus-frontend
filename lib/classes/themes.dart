import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; 

// Utility function to convert Hex string to Flutter Color
Color hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  return Color(int.parse(hex, radix: 16));
}

// Custom class to hold all theme colors and assets
class AppThemeData {
  final String name;
  final Color background;
  final Color sentBubble;
  final Color receivedBubble;
  final Color accent;
  
  // -- TEXT COLORS --
  final Color sentText;       // Text color inside the sent bubble
  final Color receivedText;   // Text color inside the received bubble
  final Color backgroundText; // Text color on the main background (titles, body)
  
  final String image;

  AppThemeData({
    required this.name,
    required this.background,
    required this.sentBubble,
    required this.receivedBubble,
    required this.accent,
    required this.sentText,
    required this.receivedText,
    required this.backgroundText,
    required this.image,
  });

  ThemeData toThemeData() {
    return ThemeData(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: accent,
        
        // Sent Bubble config
        secondary: sentBubble,
        onSecondary: sentText, // Text color on sent bubble
        
        // Background config
        background: background,
        onBackground: backgroundText, // Text color on background
        
        // Received Bubble config (Mapping to Surface)
        surface: receivedBubble,
        onSurface: receivedText, // Text color on received bubble
        
        // Accent Text
        onPrimary: background.computeLuminance() > 0.5 ? Colors.black : Colors.white,
        
        surfaceTint: receivedBubble,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: backgroundText),
        bodyMedium: TextStyle(color: backgroundText),
        titleLarge: TextStyle(color: backgroundText, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: backgroundText),
      ),
      brightness: Brightness.dark,
    );
  }
}

const String kDefaultThemeNameReadable = 'Royal Cipher Dark';
const String kThemeKey = 'selectedThemeName';

// --- Theme Definitions ---
final Map<String, Map<String, String>> _themeConstants = {
  // --- Group 1: Royal Cipher ---
  'Royal Cipher': { 
    'background': '#3a208a', 'sentBubble': '#ffe099', 'receivedBubble': '#6844a3', 'accent': '#ffa3a3',
    'sentText': '#3E2723',       // Dark Brown (Perfect for Apricot)
    'receivedText': '#ffffff',   // White
    'backgroundText': '#ffffff', // White
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Royal Cipher Dark': { 
    'background': '#000001', 'sentBubble': '#b77e20', 'receivedBubble': '#1c122e', 'accent': '#ca1d1d',
    'sentText': '#ffffff',       // White (on dark gold)
    'receivedText': '#ffffff',   // White
    'backgroundText': '#c1b5cb', // Light Lavender Gray
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 2: Electric Eclipse ---
  'Electric Eclipse': { 
    'background': '#26417c', 'sentBubble': '#66fff6', 'receivedBubble': '#4a6c93', 'accent': '#ff99f3',
    'sentText': '#000000',       // Black (Essential for Neon Cyan)
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Electric Eclipse Dark': { 
    'background': '#000000', 'sentBubble': '#0fb1a6', 'receivedBubble': '#0f1720', 'accent': '#cb27b1',
    'sentText': '#ffffff',       // White (on dark Teal)
    'receivedText': '#ffffff',
    'backgroundText': '#c6c6c6',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 3: Midnight Ocean ---
  'Midnight Ocean': { 
    'background': '#21507f', 'sentBubble': '#2affff', 'receivedBubble': '#35658d', 'accent': '#ffb366',
    'sentText': '#003333',       // Deep Teal/Black (for Cyan)
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Midnight Ocean Dark': { 
    'background': '#000000', 'sentBubble': '#007979', 'receivedBubble': '#081017', 'accent': '#ad5700',
    'sentText': '#e0ffff',       // Light Cyan White
    'receivedText': '#c2e6e6',
    'backgroundText': '#c2e6e6',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 4: Twilight Luxury ---
  'Twilight Luxury': { 
    'background': '#49495d', 'sentBubble': '#f27676', 'receivedBubble': '#666687', 'accent': '#ffe066',
    'sentText': '#3d0000',       // Dark Red/Black (for Salmon pink)
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Twilight Luxury Dark': { 
    'background': '#000000', 'sentBubble': '#a41212', 'receivedBubble': '#1b1b25', 'accent': '#a18600',
    'sentText': '#ffeaea',       // Pale Pink
    'receivedText': '#d1cdb8',
    'backgroundText': '#d1cdb8',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 5: Neon Veil ---
  'Neon Veil': { 
    'background': '#3d3d3d', 'sentBubble': '#8fff7a', 'receivedBubble': '#525252', 'accent': '#ff66ff',
    'sentText': '#003d00',       // Dark Green/Black
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Neon Veil Dark': { 
    'background': '#000000', 'sentBubble': '#25b70e', 'receivedBubble': '#000000', 'accent': '#a600a6',
    'sentText': '#ffffff',
    'receivedText': '#b8b8b8',
    'backgroundText': '#b8b8b8',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 6: Obsidian Glow ---
  'Obsidian Glow': { 
    'background': '#3d3d3d', 'sentBubble': '#82ffd3', 'receivedBubble': '#4d4d4d', 'accent': '#ffa699',
    'sentText': '#004d33',       // Dark Teal
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Obsidian Glow Dark': { 
    'background': '#000000', 'sentBubble': '#13b47b', 'receivedBubble': '#000000', 'accent': '#c32e1a',
    'sentText': '#ffffff',
    'receivedText': '#bcbcbc',
    'backgroundText': '#bcbcbc',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 7: Aurora Cipher ---
  'Aurora Cipher': { 
    'background': '#234672', 'sentBubble': '#e3ffff', 'receivedBubble': '#3b6187', 'accent': '#ffe766',
    'sentText': '#003344',       // Dark Slate
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Aurora Cipher Dark': { 
    'background': '#000000', 'sentBubble': '#42dddb', 'receivedBubble': '#080d13', 'accent': '#a18600',
    'sentText': '#003333',       // Dark Teal (Bubble is bright cyan-teal)
    'receivedText': '#cacaca',
    'backgroundText': '#cacaca',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 8: Shadow Pulse ---
  'Shadow Pulse': { 
    'background': '#454545', 'sentBubble': '#ff8b66', 'receivedBubble': '#525252', 'accent': '#66ffcd',
    'sentText': '#3d0f00',       // Dark Brown/Red
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Shadow Pulse Dark': { 
    'background': '#000000', 'sentBubble': '#ae2b00', 'receivedBubble': '#000000', 'accent': '#00ad77',
    'sentText': '#ffffff',
    'receivedText': '#bcbcbc',
    'backgroundText': '#bcbcbc',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 9: Velvet Night ---
  'Velvet Night': { 
    'background': '#3b286f', 'sentBubble': '#f3e3ff', 'receivedBubble': '#684296', 'accent': '#ffe099',
    'sentText': '#2d004d',       // Deep Purple (for light lavender bubble)
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Velvet Night Dark': { 
    'background': '#000000', 'sentBubble': '#9841df', 'receivedBubble': '#170f21', 'accent': '#bf8d1d',
    'sentText': '#ffffff',
    'receivedText': '#c0c0c0',
    'backgroundText': '#c0c0c0',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 10: Cyber Dusk ---
  'Cyber Dusk': { 
    'background': '#374352', 'sentBubble': '#ff66e3', 'receivedBubble': '#3f4c62', 'accent': '#66ffdb',
    'sentText': '#4d003d',       // Dark Magenta
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Cyber Dusk Dark': { 
    'background': '#000000', 'sentBubble': '#b30094', 'receivedBubble': '#000000', 'accent': '#00a681',
    'sentText': '#ffffff',
    'receivedText': '#bcbcbc',
    'backgroundText': '#bcbcbc',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 11: Quantum Blue ---
  'Quantum Blue': { 
    'background': '#21507f', 'sentBubble': '#2affff', 'receivedBubble': '#35658d', 'accent': '#ffb366',
    'sentText': '#003333',       // Dark Teal
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Quantum Blue Dark': { 
    'background': '#000000', 'sentBubble': '#007979', 'receivedBubble': '#081017', 'accent': '#ad5700',
    'sentText': '#ffffff',
    'receivedText': '#c0c0c0',
    'backgroundText': '#c0c0c0',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 12: Midnight Ember ---
  'Midnight Ember': { 
    'background': '#3b3857', 'sentBubble': '#ffa699', 'receivedBubble': '#484562', 'accent': '#ffe066',
    'sentText': '#4d1a15',       // Dark Red-Brown
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Midnight Ember Dark': { 
    'background': '#000000', 'sentBubble': '#bf301c', 'receivedBubble': '#000001', 'accent': '#a18600',
    'sentText': '#ffffff',
    'receivedText': '#cacaca',
    'backgroundText': '#cacaca',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 13: Neon Prism ---
  'Neon Prism': { 
    'background': '#404040', 'sentBubble': '#66ffcd', 'receivedBubble': '#525252', 'accent': '#ffa3ff',
    'sentText': '#004d39',       // Dark Green
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Neon Prism Dark': { 
    'background': '#000000', 'sentBubble': '#00b378', 'receivedBubble': '#000000', 'accent': '#c01dc0',
    'sentText': '#ffffff',
    'receivedText': '#bcbcbc',
    'backgroundText': '#bcbcbc',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 14: Cosmic Veil ---
  'Cosmic Veil': { 
    'background': '#302c69', 'sentBubble': '#f2ffff', 'receivedBubble': '#474380', 'accent': '#fff2f3',
    'sentText': '#1a237e',       // Navy Blue
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Cosmic Veil Dark': { 
    'background': '#000000', 'sentBubble': '#4de7e7', 'receivedBubble': '#0b0a14', 'accent': '#e0535f',
    'sentText': '#003333',       // Dark Teal
    'receivedText': '#c0c0c0',
    'backgroundText': '#c0c0c0',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 15: Phantom Luxe ---
  'Phantom Luxe': { 
    'background': '#404040', 'sentBubble': '#e87b89', 'receivedBubble': '#525252', 'accent': '#fbdf72',
    'sentText': '#4d141b',       // Deep Burgundy
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },
  'Phantom Luxe Dark': { 
    'background': '#000000', 'sentBubble': '#961929', 'receivedBubble': '#000000', 'accent': '#a58600',
    'sentText': '#ffffff',
    'receivedText': '#bcbcbc',
    'backgroundText': '#bcbcbc',
    'image': 'assets/app_logo_transparent_darkmode.png',
  },

  // --- Group 16: Emerald Shadow ---
  'Emerald Shadow': { 
    'background': '#491d35', 'sentBubble': '#91f7b3', 'receivedBubble': '#773c5c', 'accent': '#f9c2e7',
    'sentText': '#003d15',       // Dark Green
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Emerald Shadow Dark': { 
    'background': '#12070d', 'sentBubble': '#0ba23e', 'receivedBubble': '#331a28', 'accent': '#950e68',
    'sentText': '#ffffff',
    'receivedText': '#d4d4d4',
    'backgroundText': '#d4d4d4',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 17: Crimson Void ---
  'Crimson Void': { 
    'background': '#4b2c20', 'sentBubble': '#c9fec8', 'receivedBubble': '#774f40', 'accent': '#fb86fd',
    'sentText': '#1b4d1a',       // Dark Forest
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Crimson Void Dark': { 
    'background': '#040202', 'sentBubble': '#069603', 'receivedBubble': '#241814', 'accent': '#f704fb',
    'sentText': '#ffffff',
    'receivedText': '#d4d4d4',
    'backgroundText': '#d4d4d4',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 18: Sapphire Night ---
  'Sapphire Night': { 
    'background': '#2d7222', 'sentBubble': '#f8b2af', 'receivedBubble': '#4ca23f', 'accent': '#82f1f7',
    'sentText': '#4d100d',       // Dark Red
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Sapphire Night Dark': { 
    'background': '#030802', 'sentBubble': '#bd180f', 'receivedBubble': '#152c11', 'accent': '#0ba5ad',
    'sentText': '#ffffff',
    'receivedText': '#cccccc',
    'backgroundText': '#cccccc',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 19: Golden Abyss ---
  'Golden Abyss': { 
    'background': '#5e5726', 'sentBubble': '#c9fafc', 'receivedBubble': '#8a8147', 'accent': '#f7b8b5',
    'sentText': '#1a4d50',       // Dark Teal
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Golden Abyss Dark': { 
    'background': '#000000', 'sentBubble': '#09b0b9', 'receivedBubble': '#221f11', 'accent': '#d92017',
    'sentText': '#ffffff',
    'receivedText': '#bababa',
    'backgroundText': '#bababa',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 20: Violet Vortex ---
  'Violet Vortex': { 
    'background': '#295865', 'sentBubble': '#ff9fdd', 'receivedBubble': '#4b8291', 'accent': '#7af5a5',
    'sentText': '#4d1a38',       // Dark Purple
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Violet Vortex Dark': { 
    'background': '#030607', 'sentBubble': '#f4019f', 'receivedBubble': '#152428', 'accent': '#0b933b',
    'sentText': '#ffffff',
    'receivedText': '#c4c4c4',
    'backgroundText': '#c4c4c4',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 21: Turquoise Tempest ---
  'Turquoise Tempest': { 
    'background': '#225339', 'sentBubble': '#b2e9fa', 'receivedBubble': '#42805f', 'accent': '#f9a085',
    'sentText': '#0d3d4d',       // Dark Blue
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Turquoise Tempest Dark': { 
    'background': '#000000', 'sentBubble': '#0fbbf0', 'receivedBubble': '#112219', 'accent': '#c83609',
    'sentText': '#000000',       // Black (Cyan is bright)
    'receivedText': '#cfcfcf',
    'backgroundText': '#cfcfcf',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 22: Indigo Inferno ---
  'Indigo Inferno': { 
    'background': '#286318', 'sentBubble': '#ff708a', 'receivedBubble': '#479631', 'accent': '#80ffe8',
    'sentText': '#4d0012',       // Dark Crimson
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Indigo Inferno Dark': { 
    'background': '#081505', 'sentBubble': '#fa002e', 'receivedBubble': '#1b3a13', 'accent': '#00f0c4',
    'sentText': '#ffffff',
    'receivedText': '#c4c4c4',
    'backgroundText': '#c4c4c4',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 23: Scarlet Storm ---
  'Scarlet Storm': { 
    'background': '#4b661e', 'sentBubble': '#fd8bca', 'receivedBubble': '#73973b', 'accent': '#95f4c0',
    'sentText': '#4d1a35',       // Dark Rose
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Scarlet Storm Dark': { 
    'background': '#060802', 'sentBubble': '#c90370', 'receivedBubble': '#222c11', 'accent': '#0f8f49',
    'sentText': '#ffffff',
    'receivedText': '#cccccc',
    'backgroundText': '#cccccc',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 24: Azure Abyss ---
  'Azure Abyss': { 
    'background': '#1c3a4f', 'sentBubble': '#e78bf9', 'receivedBubble': '#39627f', 'accent': '#b4fda5',
    'sentText': '#3d0d4d',       // Deep Violet
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Azure Abyss Dark': { 
    'background': '#010304', 'sentBubble': '#cc0df2', 'receivedBubble': '#111e27', 'accent': '#2ff906',
    'sentText': '#ffffff',
    'receivedText': '#d6d6d6',
    'backgroundText': '#d6d6d6',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 25: Magenta Mirage ---
  'Magenta Mirage': { 
    'background': '#47531d', 'sentBubble': '#e690fd', 'receivedBubble': '#73823a', 'accent': '#d0fdc4',
    'sentText': '#3d104d',       // Deep Purple
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Magenta Mirage Dark': { 
    'background': '#030401', 'sentBubble': '#be04f1', 'receivedBubble': '#222711', 'accent': '#33cf07',
    'sentText': '#ffffff',
    'receivedText': '#cfcfcf',
    'backgroundText': '#cfcfcf',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 26: Lime Lurker ---
  'Lime Lurker': { 
    'background': '#306728', 'sentBubble': '#f2d882', 'receivedBubble': '#529348', 'accent': '#809dff',
    'sentText': '#3d3210',       // Dark Olive/Brown
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Lime Lurker Dark': { 
    'background': '#050b04', 'sentBubble': '#9d7c10', 'receivedBubble': '#192c16', 'accent': '#0033db',
    'sentText': '#ffffff',
    'receivedText': '#b8b8b8',
    'backgroundText': '#b8b8b8',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 27: Teal Twilight ---
  'Teal Twilight': { 
    'background': '#235b70', 'sentBubble': '#dec1fb', 'receivedBubble': '#41859f', 'accent': '#def9c2',
    'sentText': '#391a4d',       // Dark Purple
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Teal Twilight Dark': { 
    'background': '#04090c', 'sentBubble': '#4c0990', 'receivedBubble': '#13272f', 'accent': '#61b110',
    'sentText': '#ffffff',
    'receivedText': '#cccccc',
    'backgroundText': '#cccccc',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 28: Ruby Realm ---
  'Ruby Realm': { 
    'background': '#636022', 'sentBubble': '#9aa6f4', 'receivedBubble': '#918d40', 'accent': '#faf2bd',
    'sentText': '#1a224d',       // Dark Blue
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Ruby Realm Dark': { 
    'background': '#040401', 'sentBubble': '#1730d3', 'receivedBubble': '#272611', 'accent': '#9c890d',
    'sentText': '#ffffff',
    'receivedText': '#c9c9c9',
    'backgroundText': '#c9c9c9',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 29: Amber Eclipse ---
  'Amber Eclipse': { 
    'background': '#73214e', 'sentBubble': '#d6f985', 'receivedBubble': '#a43d75', 'accent': '#9569fc',
    'sentText': '#364d10',       // Dark Olive Green
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Amber Eclipse Dark': { 
    'background': '#040103', 'sentBubble': '#a3e50b', 'receivedBubble': '#290f1d', 'accent': '#4d05f5',
    'sentText': '#000000',       // Black (Lime is bright)
    'receivedText': '#cccccc',
    'backgroundText': '#cccccc',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 30: Orchid Oblivion ---
  'Orchid Oblivion': { 
    'background': '#27204b', 'sentBubble': '#75f5c4', 'receivedBubble': '#494077', 'accent': '#fe72a7',
    'sentText': '#0d4d38',       // Dark Teal
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Orchid Oblivion Dark': { 
    'background': '#040307', 'sentBubble': '#0cb072', 'receivedBubble': '#181528', 'accent': '#a2023f',
    'sentText': '#ffffff',
    'receivedText': '#d9d9d9',
    'backgroundText': '#d9d9d9',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 31: Cyan Cipher ---
  'Cyan Cipher': { 
    'background': '#754f1a', 'sentBubble': '#f8fdbe', 'receivedBubble': '#a97832', 'accent': '#c1bcfb',
    'sentText': '#4d4b10',       // Dark Brown/Gold
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Cyan Cipher Dark': { 
    'background': '#040301', 'sentBubble': '#a0ae04', 'receivedBubble': '#2b1f0d', 'accent': '#210feb',
    'sentText': '#ffffff',
    'receivedText': '#d4d4d4',
    'backgroundText': '#d4d4d4',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 32: Fuchsia Flux ---
  'Fuchsia Flux': { 
    'background': '#2a7916', 'sentBubble': '#f89ba6', 'receivedBubble': '#47ae2d', 'accent': '#9efff4',
    'sentText': '#4d1a21',       // Dark Maroon
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Fuchsia Flux Dark': { 
    'background': '#071604', 'sentBubble': '#c70f24', 'receivedBubble': '#193d10', 'accent': '#00e0c6',
    'sentText': '#ffffff',
    'receivedText': '#d6d6d6',
    'backgroundText': '#d6d6d6',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 33: Bronze Blackout ---
  'Bronze Blackout': { 
    'background': '#55561f', 'sentBubble': '#c8f9f3', 'receivedBubble': '#84853d', 'accent': '#fbc6cc',
    'sentText': '#1a4d49',       // Dark Cyan
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Bronze Blackout Dark': { 
    'background': '#000000', 'sentBubble': '#18d8c1', 'receivedBubble': '#232310', 'accent': '#b00c1f',
    'sentText': '#000000',       // Black
    'receivedText': '#b3b3b3',
    'backgroundText': '#b3b3b3',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 34: Silver Shadow ---
  'Silver Shadow': { 
    'background': '#7c561d', 'sentBubble': '#7ef278', 'receivedBubble': '#ae7f37', 'accent': '#f6bef9',
    'sentText': '#1a4d17',       // Dark Green
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Silver Shadow Dark': { 
    'background': '#000000', 'sentBubble': '#1bba12', 'receivedBubble': '#271c0c', 'accent': '#a411ac',
    'sentText': '#ffffff',
    'receivedText': '#c7c7c7',
    'backgroundText': '#c7c7c7',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },

  // --- Group 35: Platinum Pulse ---
  'Platinum Pulse': { 
    'background': '#5b1a2e', 'sentBubble': '#f7fec2', 'receivedBubble': '#8d354f', 'accent': '#bfb7fa',
    'sentText': '#4d4c10',       // Dark Olive/Gold
    'receivedText': '#ffffff',
    'backgroundText': '#ffffff',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
  'Platinum Pulse Dark': { 
    'background': '#100508', 'sentBubble': '#c9e302', 'receivedBubble': '#34141d', 'accent': '#250ecd',
    'sentText': '#000000',       // Black (Yellow is bright)
    'receivedText': '#c2c2c2',
    'backgroundText': '#c2c2c2',
    'image': 'assets/app_logo_transparent_darkmode.png'
  },
};

final List<String> _orderedThemeNames = [
  'Royal Cipher', 'Royal Cipher Dark',
  'Electric Eclipse', 'Electric Eclipse Dark',
  'Midnight Ocean', 'Midnight Ocean Dark',
  'Twilight Luxury', 'Twilight Luxury Dark',
  'Neon Veil', 'Neon Veil Dark',
  'Obsidian Glow', 'Obsidian Glow Dark',
  'Aurora Cipher', 'Aurora Cipher Dark',
  'Shadow Pulse', 'Shadow Pulse Dark',
  'Velvet Night', 'Velvet Night Dark',
  'Cyber Dusk', 'Cyber Dusk Dark',
  'Quantum Blue', 'Quantum Blue Dark',
  'Midnight Ember', 'Midnight Ember Dark',
  'Neon Prism', 'Neon Prism Dark',
  'Cosmic Veil', 'Cosmic Veil Dark',
  'Phantom Luxe', 'Phantom Luxe Dark',
  'Emerald Shadow', 'Emerald Shadow Dark',
  'Crimson Void', 'Crimson Void Dark',
  'Sapphire Night', 'Sapphire Night Dark',
  'Golden Abyss', 'Golden Abyss Dark',
  'Violet Vortex', 'Violet Vortex Dark',
  'Turquoise Tempest', 'Turquoise Tempest Dark',
  'Indigo Inferno', 'Indigo Inferno Dark',
  'Scarlet Storm', 'Scarlet Storm Dark',
  'Azure Abyss', 'Azure Abyss Dark',
  'Magenta Mirage', 'Magenta Mirage Dark',
  'Lime Lurker', 'Lime Lurker Dark',
  'Teal Twilight', 'Teal Twilight Dark',
  'Ruby Realm', 'Ruby Realm Dark',
  'Amber Eclipse', 'Amber Eclipse Dark',
  'Orchid Oblivion', 'Orchid Oblivion Dark',
  'Cyan Cipher', 'Cyan Cipher Dark',
  'Fuchsia Flux', 'Fuchsia Flux Dark',
  'Bronze Blackout', 'Bronze Blackout Dark',
  'Silver Shadow', 'Silver Shadow Dark',
  'Platinum Pulse', 'Platinum Pulse Dark',
];

AppThemeData getThemeByName(String themeName) {
  final constants = _themeConstants[themeName];

  if (constants == null) {
    print('Theme "$themeName" not found. Falling back to default: $kDefaultThemeNameReadable.');
    return getThemeByName(kDefaultThemeNameReadable);
  }

  return AppThemeData(
    name: themeName,
    background: hexToColor(constants['background']!),
    sentBubble: hexToColor(constants['sentBubble']!),
    receivedBubble: hexToColor(constants['receivedBubble']!),
    accent: hexToColor(constants['accent']!),
    
    // Updated retrievers for the new fields
    sentText: hexToColor(constants['sentText']!),
    receivedText: hexToColor(constants['receivedText']!),
    backgroundText: hexToColor(constants['backgroundText']!),
    
    image: constants['image']!,
  );
}

List<AppThemeData> getAllThemes() {
  return _orderedThemeNames.map((themeName) => getThemeByName(themeName)).toList();
}

class ThemeNotifier extends ChangeNotifier {
  AppThemeData _currentTheme;
  
  ThemeNotifier(this._currentTheme); 

  AppThemeData get currentTheme => _currentTheme;

  void setTheme(AppThemeData newTheme) async {
    if (_currentTheme.name != newTheme.name) {
      _currentTheme = newTheme;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kThemeKey, newTheme.name);
      notifyListeners();
    }
  }
}