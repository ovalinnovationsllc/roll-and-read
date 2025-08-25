import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserModel {
  final String id;
  final String displayName;
  final String emailAddress;
  final String pin;
  final bool isAdmin;
  final int gamesPlayed;
  final int gamesWon;
  final int wordsCorrect;
  final DateTime createdAt;
  final Color? playerColor;

  UserModel({
    required this.id,
    required this.displayName,
    required this.emailAddress,
    required this.pin,
    this.isAdmin = false,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.wordsCorrect = 0,
    required this.createdAt,
    this.playerColor,
  });

  // Create a new user
  factory UserModel.create({
    required String id,
    required String displayName,
    required String emailAddress,
    required String pin,
    bool isAdmin = false,
    Color? playerColor,
  }) {
    return UserModel(
      id: id,
      displayName: displayName,
      emailAddress: emailAddress,
      pin: pin,
      isAdmin: isAdmin,
      gamesPlayed: 0,
      gamesWon: 0,
      wordsCorrect: 0,
      createdAt: DateTime.now(),
      playerColor: playerColor,
    );
  }

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'emailAddress': emailAddress,
      'pin': pin,
      'isAdmin': isAdmin,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'wordsCorrect': wordsCorrect,
      'createdAt': Timestamp.fromDate(createdAt),
      'playerColor': playerColor?.value,
    };
  }

  // Create from Map (database retrieval)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.parse(value);
      if (value is Timestamp) {
        // Handle Firestore Timestamp
        return value.toDate();
      }
      return DateTime.now();
    }

    return UserModel(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? '',
      emailAddress: map['emailAddress'] ?? '',
      pin: map['pin'] ?? '',
      isAdmin: map['isAdmin'] ?? false,
      gamesPlayed: (map['gamesPlayed'] ?? 0).toInt(),
      gamesWon: (map['gamesWon'] ?? 0).toInt(),
      wordsCorrect: (map['wordsCorrect'] ?? 0).toInt(),
      createdAt: parseDateTime(map['createdAt']),
      playerColor: map['playerColor'] != null ? Color(map['playerColor']) : null,
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
      'wordsCorrect': wordsCorrect,
      'createdAt': createdAt.toIso8601String(),
      'playerColor': playerColor?.value,
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
      wordsCorrect: (json['wordsCorrect'] ?? 0).toInt(),
      createdAt: parseDateTime(json['createdAt']),
      playerColor: json['playerColor'] != null ? Color(json['playerColor']) : null,
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
    int? wordsCorrect,
    DateTime? createdAt,
    Color? playerColor,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      emailAddress: emailAddress ?? this.emailAddress,
      pin: pin ?? this.pin,
      isAdmin: isAdmin ?? this.isAdmin,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      wordsCorrect: wordsCorrect ?? this.wordsCorrect,
      createdAt: createdAt ?? this.createdAt,
      playerColor: playerColor ?? this.playerColor,
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
    return copyWith(wordsCorrect: wordsCorrect + count);
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
      other.wordsCorrect == wordsCorrect &&
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
      wordsCorrect.hashCode ^
      createdAt.hashCode;
  }

  @override
  String toString() {
    return 'UserModel(id: $id, displayName: $displayName, emailAddress: $emailAddress, pin: $pin, isAdmin: $isAdmin, gamesPlayed: $gamesPlayed, gamesWon: $gamesWon, wordsCorrect: $wordsCorrect, createdAt: $createdAt)';
  }
}