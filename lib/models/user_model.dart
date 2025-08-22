class UserModel {
  final String id;
  final String displayName;
  final String emailAddress;
  final bool isAdmin;
  final int gamesWon;
  final int wordsCorrect;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.displayName,
    required this.emailAddress,
    this.isAdmin = false,
    this.gamesWon = 0,
    this.wordsCorrect = 0,
    required this.createdAt,
  });

  // Create a new user
  factory UserModel.create({
    required String id,
    required String displayName,
    required String emailAddress,
    bool isAdmin = false,
  }) {
    return UserModel(
      id: id,
      displayName: displayName,
      emailAddress: emailAddress,
      isAdmin: isAdmin,
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
      'isAdmin': isAdmin,
      'gamesWon': gamesWon,
      'wordsCorrect': wordsCorrect,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Map (database retrieval)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? '',
      emailAddress: map['emailAddress'] ?? '',
      isAdmin: map['isAdmin'] ?? false,
      gamesWon: map['gamesWon'] ?? 0,
      wordsCorrect: map['wordsCorrect'] ?? 0,
      createdAt: map['createdAt'] != null 
        ? DateTime.parse(map['createdAt'])
        : DateTime.now(),
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
    bool? isAdmin,
    int? gamesWon,
    int? wordsCorrect,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      emailAddress: emailAddress ?? this.emailAddress,
      isAdmin: isAdmin ?? this.isAdmin,
      gamesWon: gamesWon ?? this.gamesWon,
      wordsCorrect: wordsCorrect ?? this.wordsCorrect,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper methods for incrementing stats
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
      other.isAdmin == isAdmin &&
      other.gamesWon == gamesWon &&
      other.wordsCorrect == wordsCorrect &&
      other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      displayName.hashCode ^
      emailAddress.hashCode ^
      isAdmin.hashCode ^
      gamesWon.hashCode ^
      wordsCorrect.hashCode ^
      createdAt.hashCode;
  }

  @override
  String toString() {
    return 'UserModel(id: $id, displayName: $displayName, emailAddress: $emailAddress, isAdmin: $isAdmin, gamesWon: $gamesWon, wordsCorrect: $wordsCorrect, createdAt: $createdAt)';
  }
}