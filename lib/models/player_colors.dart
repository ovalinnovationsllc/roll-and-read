import 'package:flutter/material.dart';

class PlayerColors {
  // Configurable limit for maximum students per teacher
  static const int maxStudentsPerTeacher = 30;
  
  static const List<PlayerColor> availableColors = [
    // High-contrast primary colors optimized for classroom use
    PlayerColor(name: 'Red', color: Color(0xFFE53E3E)),      // Bright Red
    PlayerColor(name: 'Blue', color: Color(0xFF3182CE)),     // Strong Blue  
    PlayerColor(name: 'Green', color: Color(0xFF38A169)),    // Forest Green
    PlayerColor(name: 'Orange', color: Color(0xFFDD6B20)),   // Vivid Orange
    PlayerColor(name: 'Purple', color: Color(0xFF805AD5)),   // Rich Purple
    PlayerColor(name: 'Teal', color: Color(0xFF319795)),     // Strong Teal
    PlayerColor(name: 'Pink', color: Color(0xFFD53F8C)),     // Hot Pink
    PlayerColor(name: 'Indigo', color: Color(0xFF553C9A)),   // Deep Indigo
    PlayerColor(name: 'Lime', color: Color(0xFF84CC16)),     // Bright Lime
    PlayerColor(name: 'Amber', color: Color(0xFFD69E2E)),    // Golden Amber
    PlayerColor(name: 'Cyan', color: Color(0xFF00B5D8)),     // Electric Cyan
    PlayerColor(name: 'Brown', color: Color(0xFF8B4513)),    // Chocolate Brown
    
    // Extended colors for larger classrooms (13-30 students)
    PlayerColor(name: 'Magenta', color: Color(0xFFE91E63)),  // Bright Magenta
    PlayerColor(name: 'Navy', color: Color(0xFF1A365D)),     // Dark Navy
    PlayerColor(name: 'Olive', color: Color(0xFF6B7280)),    // Olive Green
    PlayerColor(name: 'Maroon', color: Color(0xFF7C2D12)),   // Dark Maroon
    PlayerColor(name: 'Gold', color: Color(0xFFEAB308)),     // Bright Gold
    PlayerColor(name: 'Coral', color: Color(0xFFFF7F7F)),    // Light Coral
    PlayerColor(name: 'Turquoise', color: Color(0xFF40E0D0)), // Turquoise
    PlayerColor(name: 'Lavender', color: Color(0xFF9F7AEA)), // Light Lavender
    PlayerColor(name: 'Mint', color: Color(0xFF68D391)),     // Mint Green
    PlayerColor(name: 'Salmon', color: Color(0xFFFA8072)),   // Salmon Pink
    PlayerColor(name: 'Steel', color: Color(0xFF4682B4)),    // Steel Blue
    PlayerColor(name: 'Plum', color: Color(0xFFDDA0DD)),     // Light Plum
    PlayerColor(name: 'Forest', color: Color(0xFF228B22)),   // Forest Green
    PlayerColor(name: 'Crimson', color: Color(0xFFDC143C)),  // Deep Crimson
    PlayerColor(name: 'Aqua', color: Color(0xFF00FFFF)),     // Bright Aqua
    PlayerColor(name: 'Violet', color: Color(0xFF8A2BE2)),   // Blue Violet
    PlayerColor(name: 'Khaki', color: Color(0xFFF0E68C)),    // Light Khaki
    PlayerColor(name: 'Rose', color: Color(0xFFFF69B4)),     // Hot Pink Rose
    PlayerColor(name: 'Slate', color: Color(0xFF708090)),    // Slate Gray
  ];

  static Color getDefaultColor() => Colors.blue;
  
  // Get available colors up to the configured limit
  static List<PlayerColor> getAvailableColorsForStudents() {
    return availableColors.take(maxStudentsPerTeacher).toList();
  }
  
  static String getColorName(Color color) {
    for (final playerColor in availableColors) {
      if (playerColor.color.value == color.value) {
        return playerColor.name;
      }
    }
    return 'Custom';
  }
  
  static List<Color> getUsedColorsInGame(List<dynamic> players) {
    return players
        .where((player) => player['playerColor'] != null)
        .map((player) => Color(player['playerColor']))
        .toList();
  }
  
  static List<PlayerColor> getAvailableColorsForGame(List<dynamic> players) {
    final usedColors = getUsedColorsInGame(players);
    return availableColors
        .where((playerColor) => !usedColors.any((used) => used.value == playerColor.color.value))
        .toList();
  }
}

class PlayerColor {
  final String name;
  final Color color;
  
  const PlayerColor({
    required this.name,
    required this.color,
  });
}