// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:erebusv3/classes/themes.dart';
import 'package:provider/provider.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch for theme changes
    final themeNotifier = context.watch<ThemeNotifier>();
    final currentTheme = themeNotifier.currentTheme;
    final allThemes = getAllThemes();

    return Scaffold(
      // We set the background color of the scaffold to match the theme background
      backgroundColor: currentTheme.background,
      appBar: AppBar(
        title: Text(
          'Theme Preview',
          style: TextStyle(color: currentTheme.backgroundText),
        ),
        backgroundColor: currentTheme.receivedBubble,
        centerTitle: true,
        elevation: 0,
        iconTheme: IconThemeData(color: currentTheme.backgroundText),
      ),
      body: Column(
        children: [
          // 1. THEME SELECTOR AREA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: currentTheme.receivedBubble.withOpacity(0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Choose Style:",
                  style: TextStyle(
                    color: currentTheme.backgroundText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: currentTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: currentTheme.accent, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentTheme.name,
                      dropdownColor: currentTheme.receivedBubble,
                      icon: Icon(Icons.arrow_drop_down, color: currentTheme.accent),
                      items: allThemes.map<DropdownMenuItem<String>>((AppThemeData themeData) {
                        return DropdownMenuItem<String>(
                          value: themeData.name,
                          child: Text(
                            themeData.name,
                            style: TextStyle(
                              color: currentTheme.backgroundText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newThemeName) {
                        if (newThemeName != null && newThemeName != currentTheme.name) {
                          themeNotifier.setTheme(getThemeByName(newThemeName));
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. CHAT AREA (Wallpaper + Bubbles)
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: currentTheme.background,
                // Apply the theme image as the chat wallpaper
                image: DecorationImage(
                  image: AssetImage(currentTheme.image),
                  fit: BoxFit.cover,
                  // Add a slight dark filter so text remains readable over the image
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.1), 
                    BlendMode.darken
                  ),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Date separator simulation
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Today",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  
                  // Mock Messages
                  _buildChatBubble(
                    context: context,
                    text: "Hey! Have you seen the new update?",
                    isMe: false,
                    theme: currentTheme,
                  ),
                  _buildChatBubble(
                    context: context,
                    text: "Yeah, I'm testing the theme system right now. 🎨",
                    isMe: true,
                    theme: currentTheme,
                  ),
                   _buildChatBubble(
                    context: context,
                    text: "How does this color combination look to you?",
                    isMe: true,
                    theme: currentTheme,
                  ),
                  _buildChatBubble(
                    context: context,
                    text: "It looks fantastic! The accent color really pops against the background.",
                    isMe: false,
                    theme: currentTheme,
                  ),
                ],
              ),
            ),
          ),

          // 3. INPUT AREA SIMULATION
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: currentTheme.receivedBubble, // Usually inputs act like "surface" colors
            child: Row(
              children: [
                Icon(Icons.add, color: currentTheme.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: currentTheme.background.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      "Type a message...",
                      style: TextStyle(color: currentTheme.backgroundText.withOpacity(0.6)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Send Button using Accent Color
                CircleAvatar(
                  backgroundColor: currentTheme.accent,
                  radius: 20,
                  child: Icon(Icons.send, color: currentTheme.background, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to build chat bubbles dynamically
  Widget _buildChatBubble({
    required BuildContext context,
    required String text,
    required bool isMe,
    required AppThemeData theme,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? theme.sentBubble : theme.receivedBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe ? theme.sentText : theme.receivedText,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}