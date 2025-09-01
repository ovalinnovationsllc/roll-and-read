import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StudentModel {
  final String studentId;
  final String teacherId;
  final String displayName;
  final String avatarUrl; // Could be an emoji or simple avatar
  final Color playerColor;
  final int gamesPlayed;
  final int gamesWon;
  final int wordsRead;
  final DateTime createdAt;
  final DateTime lastPlayedAt;
  final bool isActive;

  StudentModel({
    required this.studentId,
    required this.teacherId,
    required this.displayName,
    required this.avatarUrl,
    required this.playerColor,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.wordsRead = 0,
    required this.createdAt,
    required this.lastPlayedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'teacherId': teacherId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'playerColor': playerColor.value,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'wordsRead': wordsRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastPlayedAt': Timestamp.fromDate(lastPlayedAt),
      'isActive': isActive,
    };
  }

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    return StudentModel(
      studentId: map['studentId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      displayName: map['displayName'] ?? 'Student',
      avatarUrl: map['avatarUrl'] ?? '😊',
      playerColor: Color(map['playerColor'] ?? Colors.blue.value),
      gamesPlayed: (map['gamesPlayed'] ?? 0).toInt(),
      gamesWon: (map['gamesWon'] ?? 0).toInt(),
      wordsRead: (map['wordsRead'] ?? 0).toInt(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastPlayedAt: (map['lastPlayedAt'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
    );
  }

  StudentModel copyWith({
    String? studentId,
    String? teacherId,
    String? displayName,
    String? avatarUrl,
    Color? playerColor,
    int? gamesPlayed,
    int? gamesWon,
    int? wordsRead,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    bool? isActive,
  }) {
    return StudentModel(
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      playerColor: playerColor ?? this.playerColor,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      wordsRead: wordsRead ?? this.wordsRead,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

// Preset avatars for easy selection
class StudentAvatars {
  static const List<String> animalEmojis = [
    '🐶', '🐱', '🐭', '🐹', '🐰', '🦊',
    '🐻', '🐼', '🐨', '🐯', '🦁', '🐮',
    '🐷', '🐸', '🐵', '🐔', '🐧', '🐦',
    '🦄', '🐝', '🦋', '🐢', '🐠', '🐙',
  ];
  
  // Fallback simple avatars (letters) for when emojis don't display
  static const List<String> letterAvatars = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
    'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  static const List<Color> colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.amber,
    Colors.indigo,
    Colors.lime,
    Colors.cyan,
    Colors.brown,
  ];
}