import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  // Create a new user
  factory UserModel.create({
    required String id,
    required String displayName,
    required String emailAddress,
    required String pin,
    bool isAdmin = false,
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
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() => toMap();

  // Create from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel.fromMap(json);

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