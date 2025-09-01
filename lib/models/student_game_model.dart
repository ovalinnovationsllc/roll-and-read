import 'package:cloud_firestore/cloud_firestore.dart';

class StudentGameModel {
  final String gameId;
  final String gameCode; // Simple code like "BLUE", "123", "CATS"
  final String teacherId;
  final String teacherName;
  final List<StudentPlayer> players;
  final String gameMode; // 'waiting', 'active', 'completed'
  final DateTime createdAt;
  final DateTime? startedAt;
  final String wordListType; // 'long_u', 'ai_generated', etc.
  final int maxPlayers;
  
  StudentGameModel({
    required this.gameId,
    required this.gameCode,
    required this.teacherId,
    required this.teacherName,
    required this.players,
    this.gameMode = 'waiting',
    required this.createdAt,
    this.startedAt,
    this.wordListType = 'long_u',
    this.maxPlayers = 2,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'gameCode': gameCode,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'players': players.map((p) => p.toMap()).toList(),
      'gameMode': gameMode,
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'wordListType': wordListType,
      'maxPlayers': maxPlayers,
    };
  }
  
  factory StudentGameModel.fromMap(Map<String, dynamic> map) {
    return StudentGameModel(
      gameId: map['gameId'] ?? '',
      gameCode: map['gameCode'] ?? '',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      players: (map['players'] as List<dynamic>?)
          ?.map((p) => StudentPlayer.fromMap(p as Map<String, dynamic>))
          .toList() ?? [],
      gameMode: map['gameMode'] ?? 'waiting',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      startedAt: map['startedAt'] != null 
          ? (map['startedAt'] as Timestamp).toDate() 
          : null,
      wordListType: map['wordListType'] ?? 'long_u',
      maxPlayers: map['maxPlayers'] ?? 2,
    );
  }
  
  StudentGameModel copyWith({
    String? gameId,
    String? gameCode,
    String? teacherId,
    String? teacherName,
    List<StudentPlayer>? players,
    String? gameMode,
    DateTime? createdAt,
    DateTime? startedAt,
    String? wordListType,
    int? maxPlayers,
  }) {
    return StudentGameModel(
      gameId: gameId ?? this.gameId,
      gameCode: gameCode ?? this.gameCode,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      players: players ?? this.players,
      gameMode: gameMode ?? this.gameMode,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      wordListType: wordListType ?? this.wordListType,
      maxPlayers: maxPlayers ?? this.maxPlayers,
    );
  }
  
  // Helper methods
  bool get isFull => players.length >= maxPlayers;
  bool get canStart => players.length >= 2;
  bool get isWaiting => gameMode == 'waiting';
  bool get isActive => gameMode == 'active';
  bool get isCompleted => gameMode == 'completed';
  
  StudentPlayer? findPlayerBySlot(int slot) {
    try {
      return players.where((p) => p.playerSlot == slot).first;
    } catch (e) {
      return null;
    }
  }
  
  int get nextAvailableSlot {
    for (int i = 1; i <= maxPlayers; i++) {
      if (!players.any((p) => p.playerSlot == i)) {
        return i;
      }
    }
    return -1; // No slots available
  }
}

class StudentPlayer {
  final String playerId; // Auto-generated
  final String playerName; // "Player 1" or custom name
  final int playerSlot; // 1, 2, 3, 4, etc.
  final String avatarColor; // 'red', 'blue', 'green', 'yellow', etc.
  final String avatarIcon; // 'cat', 'dog', 'star', 'heart', etc.
  final DateTime joinedAt;
  final bool isConnected;
  
  StudentPlayer({
    required this.playerId,
    required this.playerName,
    required this.playerSlot,
    required this.avatarColor,
    required this.avatarIcon,
    required this.joinedAt,
    this.isConnected = true,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'playerSlot': playerSlot,
      'avatarColor': avatarColor,
      'avatarIcon': avatarIcon,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isConnected': isConnected,
    };
  }
  
  factory StudentPlayer.fromMap(Map<String, dynamic> map) {
    return StudentPlayer(
      playerId: map['playerId'] ?? '',
      playerName: map['playerName'] ?? 'Player',
      playerSlot: map['playerSlot'] ?? 1,
      avatarColor: map['avatarColor'] ?? 'blue',
      avatarIcon: map['avatarIcon'] ?? 'star',
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
      isConnected: map['isConnected'] ?? true,
    );
  }
  
  StudentPlayer copyWith({
    String? playerId,
    String? playerName,
    int? playerSlot,
    String? avatarColor,
    String? avatarIcon,
    DateTime? joinedAt,
    bool? isConnected,
  }) {
    return StudentPlayer(
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      playerSlot: playerSlot ?? this.playerSlot,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      joinedAt: joinedAt ?? this.joinedAt,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

// Predefined avatar combinations for easy selection
class StudentAvatars {
  static const List<Map<String, String>> defaultAvatars = [
    {'color': 'red', 'icon': 'cat', 'name': 'Red Cat'},
    {'color': 'blue', 'icon': 'dog', 'name': 'Blue Dog'},
    {'color': 'green', 'icon': 'star', 'name': 'Green Star'},
    {'color': 'yellow', 'icon': 'heart', 'name': 'Yellow Heart'},
    {'color': 'purple', 'icon': 'butterfly', 'name': 'Purple Butterfly'},
    {'color': 'orange', 'icon': 'sun', 'name': 'Orange Sun'},
  ];
  
  static const List<String> gameCodes = [
    'CATS', 'DOGS', 'BLUE', 'RED', 'SUN', 'MOON',
    'BIRD', 'FISH', 'TREE', 'STAR', 'PLAY', 'FUN',
    '123', '456', '789', 'ABC', 'XYZ', 'WIN'
  ];
  
  static String generateRandomCode() {
    final random = DateTime.now().millisecondsSinceEpoch % gameCodes.length;
    return gameCodes[random];
  }
}