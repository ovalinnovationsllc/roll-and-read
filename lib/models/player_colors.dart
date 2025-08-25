import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class PlayerColors {
  static const List<PlayerColor> availableColors = [
    PlayerColor(name: 'Red', color: Colors.red),
    PlayerColor(name: 'Orange', color: Colors.orange),
    PlayerColor(name: 'Yellow', color: Colors.yellow),
    PlayerColor(name: 'Green', color: Colors.green),
    PlayerColor(name: 'Blue', color: Colors.blue),
    PlayerColor(name: 'Purple', color: Colors.purple),
    PlayerColor(name: 'Pink', color: Colors.pink),
    PlayerColor(name: 'Gray', color: Colors.grey),
  ];

  static Color getDefaultColor() => Colors.blue;
  
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