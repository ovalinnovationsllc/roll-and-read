import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserModel {
  final String id;
  final String displayName;
  final String emailAddress;
  final bool isAdmin;
  final DateTime createdAt;
  
  // Teacher-only fields
  final String? pin;  // Only for teachers (admin login)
  
  // Student-only fields
  final String? teacherId;  // Which teacher owns this student
  final int gamesPlayed;
  final int gamesWon;
  final int wordsRead;  // Renamed from wordsCorrect for clarity
  final DateTime? lastPlayedAt;
  final Color? playerColor;
  final String? avatarUrl;

  UserModel({
    required this.id,
    required this.displayName,
    required this.emailAddress,
    this.isAdmin = false,
    required this.createdAt,
    // Teacher fields
    this.pin,
    // Student fields
    this.teacherId,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.wordsRead = 0,
    this.lastPlayedAt,
    this.playerColor,
    this.avatarUrl,
  });

  // Create a new teacher
  factory UserModel.createTeacher({
    required String id,
    required String displayName,
    required String emailAddress,
    String? pin, // Allow null for Firebase Auth teachers
  }) {
    return UserModel(
      id: id,
      displayName: displayName,
      emailAddress: emailAddress,
      isAdmin: true,
      pin: pin,
      createdAt: DateTime.now(),
    );
  }

  // Create a new student
  factory UserModel.createStudent({
    required String id,
    required String displayName,
    required String teacherId,
    Color? playerColor,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id,
      displayName: displayName,
      emailAddress: '${id}@student.local', // Generated email for students
      isAdmin: false,
      teacherId: teacherId,
      playerColor: playerColor,
      avatarUrl: avatarUrl,
      createdAt: DateTime.now(),
      lastPlayedAt: DateTime.now(),
    );
  }

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'displayName': displayName,
      'emailAddress': emailAddress,
      'isAdmin': isAdmin,
      'createdAt': Timestamp.fromDate(createdAt),
    };
    
    // Add teacher-specific fields
    if (isAdmin && pin != null) {
      map['pin'] = pin;
    }
    
    // Add student-specific fields
    if (!isAdmin) {
      map['teacherId'] = teacherId;
      map['gamesPlayed'] = gamesPlayed;
      map['gamesWon'] = gamesWon;
      map['wordsRead'] = wordsRead;
      if (lastPlayedAt != null) {
        map['lastPlayedAt'] = Timestamp.fromDate(lastPlayedAt!);
      }
      if (playerColor != null) {
        map['playerColor'] = playerColor!.value;
      }
      if (avatarUrl != null) {
        map['avatarUrl'] = avatarUrl;
      }
    }
    
    return map;
  }

  // Create from Map (database retrieval)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.parse(value);
      if (value is Timestamp) {
        return value.toDate();
      }
      return DateTime.now();
    }

    DateTime? parseNullableDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.parse(value);
      if (value is Timestamp) {
        return value.toDate();
      }
      return null;
    }

    final isAdmin = map['isAdmin'] ?? false;

    return UserModel(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? '',
      emailAddress: map['emailAddress'] ?? '',
      isAdmin: isAdmin,
      createdAt: parseDateTime(map['createdAt']),
      // Teacher fields
      pin: isAdmin ? map['pin'] : null,
      // Student fields  
      teacherId: !isAdmin ? map['teacherId'] : null,
      gamesPlayed: (map['gamesPlayed'] ?? 0).toInt(),
      gamesWon: (map['gamesWon'] ?? 0).toInt(),
      wordsRead: (map['wordsRead'] ?? map['wordsCorrect'] ?? 0).toInt(), // Support old field name
      lastPlayedAt: parseNullableDateTime(map['lastPlayedAt']),
      playerColor: map['playerColor'] != null ? Color(map['playerColor']) : null,
      avatarUrl: map['avatarUrl'],
    );
  }

  // Convert to JSON (for session storage - uses ISO strings instead of Timestamps)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'emailAddress': emailAddress,
      'pin': pin,
      'isAdmin': isAdmin,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'wordsRead': wordsRead,
      'createdAt': createdAt.toIso8601String(),
      'playerColor': playerColor?.value,
      'avatarUrl': avatarUrl,
    };
  }

  // Create from JSON (for session storage - handles ISO strings)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      if (value is Timestamp) {
        return value.toDate();
      }
      return DateTime.now();
    }

    return UserModel(
      id: json['id'] ?? '',
      displayName: json['displayName'] ?? '',
      emailAddress: json['emailAddress'] ?? '',
      pin: json['pin'] ?? '',
      isAdmin: json['isAdmin'] ?? false,
      gamesPlayed: (json['gamesPlayed'] ?? 0).toInt(),
      gamesWon: (json['gamesWon'] ?? 0).toInt(),
      wordsRead: (json['wordsRead'] ?? json['wordsCorrect'] ?? 0).toInt(),
      createdAt: parseDateTime(json['createdAt']),
      playerColor: json['playerColor'] != null ? Color(json['playerColor']) : null,
      avatarUrl: json['avatarUrl'],
    );
  }

  // Copy with method for updating user data
  UserModel copyWith({
    String? id,
    String? displayName,
    String? emailAddress,
    String? pin,
    bool? isAdmin,
    int? gamesPlayed,
    int? gamesWon,
    int? wordsRead,
    String? teacherId,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    Color? playerColor,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      emailAddress: emailAddress ?? this.emailAddress,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      pin: pin ?? this.pin,
      teacherId: teacherId ?? this.teacherId,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      wordsRead: wordsRead ?? this.wordsRead,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      playerColor: playerColor ?? this.playerColor,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  // Helper methods for incrementing stats
  UserModel incrementGamesPlayed() {
    return copyWith(gamesPlayed: gamesPlayed + 1);
  }

  UserModel incrementGamesWon() {
    return copyWith(gamesWon: gamesWon + 1);
  }

  UserModel incrementWordsCorrect([int count = 1]) {
    return copyWith(wordsRead: wordsRead + count);
  }

  // Equality operator
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is UserModel &&
      other.id == id &&
      other.displayName == displayName &&
      other.emailAddress == emailAddress &&
      other.pin == pin &&
      other.isAdmin == isAdmin &&
      other.gamesPlayed == gamesPlayed &&
      other.gamesWon == gamesWon &&
      other.wordsRead == wordsRead &&
      other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      displayName.hashCode ^
      emailAddress.hashCode ^
      pin.hashCode ^
      isAdmin.hashCode ^
      gamesPlayed.hashCode ^
      gamesWon.hashCode ^
      wordsRead.hashCode ^
      createdAt.hashCode;
  }

  @override
  String toString() {
    return 'UserModel(id: $id, displayName: $displayName, emailAddress: $emailAddress, pin: $pin, isAdmin: $isAdmin, gamesPlayed: $gamesPlayed, gamesWon: $gamesWon, wordsRead: $wordsRead, createdAt: $createdAt)';
  }
}