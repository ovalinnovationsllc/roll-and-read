import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StudentPlayerProfile {
  final String profileId;
  final String playerName;
  final String avatarColor;
  final String avatarIcon;
  final String? teacherId; // If associated with a specific teacher
  final int gamesPlayed;
  final int wordsRead;
  final int turnsPlayed;
  final DateTime createdAt;
  final DateTime lastPlayedAt;
  final String? simplePin; // Simple 4-digit PIN for students to remember

  StudentPlayerProfile({
    required this.profileId,
    required this.playerName,
    required this.avatarColor,
    required this.avatarIcon,
    this.teacherId,
    this.gamesPlayed = 0,
    this.wordsRead = 0,
    this.turnsPlayed = 0,
    required this.createdAt,
    required this.lastPlayedAt,
    this.simplePin,
  });

  Map<String, dynamic> toMap() {
    return {
      'profileId': profileId,
      'playerName': playerName,
      'avatarColor': avatarColor,
      'avatarIcon': avatarIcon,
      'teacherId': teacherId,
      'gamesPlayed': gamesPlayed,
      'wordsRead': wordsRead,
      'turnsPlayed': turnsPlayed,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastPlayedAt': Timestamp.fromDate(lastPlayedAt),
      'simplePin': simplePin,
    };
  }

  factory StudentPlayerProfile.fromMap(Map<String, dynamic> map) {
    return StudentPlayerProfile(
      profileId: map['profileId'] ?? '',
      playerName: map['playerName'] ?? 'Player',
      avatarColor: map['avatarColor'] ?? 'blue',
      avatarIcon: map['avatarIcon'] ?? 'star',
      teacherId: map['teacherId'],
      gamesPlayed: (map['gamesPlayed'] ?? 0).toInt(),
      wordsRead: (map['wordsRead'] ?? 0).toInt(),
      turnsPlayed: (map['turnsPlayed'] ?? 0).toInt(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastPlayedAt: (map['lastPlayedAt'] as Timestamp).toDate(),
      simplePin: map['simplePin'],
    );
  }

  StudentPlayerProfile copyWith({
    String? profileId,
    String? playerName,
    String? avatarColor,
    String? avatarIcon,
    String? teacherId,
    int? gamesPlayed,
    int? wordsRead,
    int? turnsPlayed,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    String? simplePin,
  }) {
    return StudentPlayerProfile(
      profileId: profileId ?? this.profileId,
      playerName: playerName ?? this.playerName,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      teacherId: teacherId ?? this.teacherId,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wordsRead: wordsRead ?? this.wordsRead,
      turnsPlayed: turnsPlayed ?? this.turnsPlayed,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      simplePin: simplePin ?? this.simplePin,
    );
  }

  // Helper methods for stats
  StudentPlayerProfile incrementGamesPlayed() {
    return copyWith(
      gamesPlayed: gamesPlayed + 1,
      lastPlayedAt: DateTime.now(),
    );
  }

  StudentPlayerProfile addWordsRead(int count) {
    return copyWith(
      wordsRead: wordsRead + count,
      lastPlayedAt: DateTime.now(),
    );
  }

  StudentPlayerProfile incrementTurnsPlayed() {
    return copyWith(
      turnsPlayed: turnsPlayed + 1,
      lastPlayedAt: DateTime.now(),
    );
  }

  // Get player color as Flutter Color
  Color getPlayerColor() {
    switch (avatarColor.toLowerCase()) {
      case 'red': return Colors.red;
      case 'blue': return Colors.blue;
      case 'green': return Colors.green;
      case 'yellow': return Colors.orange;
      case 'purple': return Colors.purple;
      case 'pink': return Colors.pink;
      case 'teal': return Colors.teal;
      case 'orange': return Colors.deepOrange;
      default: return Colors.blue;
    }
  }

  // Get player icon
  IconData getPlayerIcon() {
    switch (avatarIcon.toLowerCase()) {
      case 'star': return Icons.star;
      case 'heart': return Icons.favorite;
      case 'cat': return Icons.pets;
      case 'dog': return Icons.pets;
      case 'sun': return Icons.wb_sunny;
      case 'moon': return Icons.nights_stay;
      case 'flower': return Icons.local_florist;
      case 'butterfly': return Icons.flutter_dash;
      default: return Icons.person;
    }
  }
}