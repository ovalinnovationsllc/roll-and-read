import 'package:cloud_firestore/cloud_firestore.dart';

class GameSessionModel {
  final String gameId;
  final String createdBy; // admin user ID
  final String gameName;
  final List<String> playerIds; // up to maxPlayers player IDs
  final List<PlayerInGame> players; // player details
  final GameStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? winnerId;
  final bool useAIWords;
  final String? aiPrompt;
  final String? difficulty;
  final List<List<String>>? wordGrid; // 6x6 grid of words
  final int maxPlayers; // Maximum number of players

  GameSessionModel({
    required this.gameId,
    required this.createdBy,
    required this.gameName,
    this.playerIds = const [],
    this.players = const [],
    this.status = GameStatus.waitingForPlayers,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.winnerId,
    this.useAIWords = false,
    this.aiPrompt,
    this.difficulty,
    this.wordGrid,
    this.maxPlayers = 2, // Default to 2 players
  });

  // Create a new game session
  factory GameSessionModel.create({
    required String gameId,
    required String createdBy,
    required String gameName,
    bool useAIWords = false,
    String? aiPrompt,
    String? difficulty,
    List<List<String>>? wordGrid,
    int maxPlayers = 2,
  }) {
    return GameSessionModel(
      gameId: gameId,
      createdBy: createdBy,
      gameName: gameName,
      createdAt: DateTime.now(),
      useAIWords: useAIWords,
      aiPrompt: aiPrompt,
      difficulty: difficulty,
      wordGrid: wordGrid,
      maxPlayers: maxPlayers,
    );
  }

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    // Flatten the 2D array for Firestore (which doesn't support nested arrays)
    List<String>? flatWordGrid;
    if (wordGrid != null) {
      flatWordGrid = [];
      for (var row in wordGrid!) {
        flatWordGrid.addAll(row);
      }
    }
    
    return {
      'gameId': gameId,
      'createdBy': createdBy,
      'gameName': gameName,
      'playerIds': playerIds,
      'players': players.map((p) => p.toMap()).toList(),
      'status': status.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'winnerId': winnerId,
      'useAIWords': useAIWords,
      'aiPrompt': aiPrompt,
      'difficulty': difficulty,
      'wordGrid': flatWordGrid, // Store as flat array
      'wordGridRows': 6, // Store dimensions for reconstruction
      'wordGridCols': 6,
      'maxPlayers': maxPlayers,
    };
  }

  // Convert to JSON (for session storage - uses ISO strings instead of Timestamps)
  Map<String, dynamic> toJson() {
    // Flatten the 2D array for storage (similar to toMap but with ISO strings)
    List<String>? flatWordGrid;
    if (wordGrid != null) {
      flatWordGrid = [];
      for (var row in wordGrid!) {
        flatWordGrid.addAll(row);
      }
    }
    
    return {
      'gameId': gameId,
      'createdBy': createdBy,
      'gameName': gameName,
      'playerIds': playerIds,
      'players': players.map((p) => p.toJson()).toList(),
      'status': status.toString(),
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'winnerId': winnerId,
      'useAIWords': useAIWords,
      'aiPrompt': aiPrompt,
      'difficulty': difficulty,
      'wordGrid': flatWordGrid, // Store as flat array
      'wordGridRows': 6, // Store dimensions for reconstruction
      'wordGridCols': 6,
      'maxPlayers': maxPlayers,
    };
  }

  // Create from JSON (for session storage - handles ISO strings)
  factory GameSessionModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    DateTime? parseNullableDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      if (value is Timestamp) return value.toDate();
      return null;
    }

    List<PlayerInGame> parsePlayersList(dynamic playersData) {
      if (playersData == null) return [];
      if (playersData is! List) return [];
      return playersData
          .map((p) => PlayerInGame.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    List<List<String>>? parseWordGrid(dynamic gridData, Map<String, dynamic> map) {
      if (gridData == null) return null;
      if (gridData is! List) return null;
      
      try {
        // Reconstruct 2D array from flat array
        final flatGrid = List<String>.from(gridData);
        final rows = (map['wordGridRows'] ?? 6) as int;
        final cols = (map['wordGridCols'] ?? 6) as int;
        
        if (flatGrid.length != rows * cols) {
          // If size doesn't match, return null
          return null;
        }
        
        List<List<String>> grid = [];
        for (int i = 0; i < rows; i++) {
          final startIdx = i * cols;
          final endIdx = startIdx + cols;
          grid.add(flatGrid.sublist(startIdx, endIdx));
        }
        return grid;
      } catch (e) {
        return null;
      }
    }

    return GameSessionModel(
      gameId: json['gameId'] ?? '',
      createdBy: json['createdBy'] ?? '',
      gameName: json['gameName'] ?? '',
      playerIds: List<String>.from(json['playerIds'] ?? []),
      players: parsePlayersList(json['players']),
      status: GameStatus.values.firstWhere(
        (s) => s.toString() == json['status'],
        orElse: () => GameStatus.waitingForPlayers,
      ),
      createdAt: parseDateTime(json['createdAt']),
      startedAt: parseNullableDateTime(json['startedAt']),
      endedAt: parseNullableDateTime(json['endedAt']),
      winnerId: json['winnerId'],
      useAIWords: json['useAIWords'] ?? false,
      aiPrompt: json['aiPrompt'],
      difficulty: json['difficulty'],
      wordGrid: parseWordGrid(json['wordGrid'], json),
      maxPlayers: json['maxPlayers'] ?? 2, // Default to 2 players
    );
  }

  // Create from Map (database retrieval)
  factory GameSessionModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.parse(value);
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    DateTime? parseNullableDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.parse(value);
      if (value is Timestamp) return value.toDate();
      return null;
    }

    List<PlayerInGame> parsePlayersList(dynamic playersData) {
      if (playersData == null) return [];
      if (playersData is! List) return [];
      
      return playersData.asMap().entries.map((entry) {
        final playerIndex = entry.key;
        final playerData = Map<String, dynamic>.from(entry.value);
        
        return PlayerInGame.fromMap(playerData);
      }).toList();
    }

    List<List<String>>? parseWordGrid(dynamic gridData, Map<String, dynamic> map) {
      if (gridData == null) return null;
      if (gridData is! List) return null;
      
      try {
        // Reconstruct 2D array from flat array
        final flatGrid = List<String>.from(gridData);
        final rows = (map['wordGridRows'] ?? 6) as int;
        final cols = (map['wordGridCols'] ?? 6) as int;
        
        if (flatGrid.length != rows * cols) {
          // If size doesn't match, return null
          return null;
        }
        
        List<List<String>> grid = [];
        for (int i = 0; i < rows; i++) {
          final startIdx = i * cols;
          final endIdx = startIdx + cols;
          grid.add(flatGrid.sublist(startIdx, endIdx));
        }
        return grid;
      } catch (e) {
        return null;
      }
    }

    return GameSessionModel(
      gameId: map['gameId'] ?? '',
      createdBy: map['createdBy'] ?? '',
      gameName: map['gameName'] ?? '',
      playerIds: List<String>.from(map['playerIds'] ?? []),
      players: parsePlayersList(map['players']),
      status: GameStatus.values.firstWhere(
        (s) => s.toString() == map['status'],
        orElse: () => GameStatus.waitingForPlayers,
      ),
      createdAt: parseDateTime(map['createdAt']),
      startedAt: parseNullableDateTime(map['startedAt']),
      endedAt: parseNullableDateTime(map['endedAt']),
      winnerId: map['winnerId'],
      useAIWords: map['useAIWords'] ?? false,
      aiPrompt: map['aiPrompt'],
      difficulty: map['difficulty'],
      wordGrid: parseWordGrid(map['wordGrid'], map),
      maxPlayers: map['maxPlayers'] ?? 2, // Default to 2 players
    );
  }

  // Copy with method for updates
  GameSessionModel copyWith({
    String? gameId,
    String? createdBy,
    String? gameName,
    List<String>? playerIds,
    List<PlayerInGame>? players,
    GameStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    String? winnerId,
    bool? useAIWords,
    String? aiPrompt,
    String? difficulty,
    List<List<String>>? wordGrid,
    int? maxPlayers,
  }) {
    return GameSessionModel(
      gameId: gameId ?? this.gameId,
      createdBy: createdBy ?? this.createdBy,
      gameName: gameName ?? this.gameName,
      playerIds: playerIds ?? this.playerIds,
      players: players ?? this.players,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      winnerId: winnerId ?? this.winnerId,
      useAIWords: useAIWords ?? this.useAIWords,
      aiPrompt: aiPrompt ?? this.aiPrompt,
      difficulty: difficulty ?? this.difficulty,
      wordGrid: wordGrid ?? this.wordGrid,
      maxPlayers: maxPlayers ?? this.maxPlayers,
    );
  }

  // Helper methods
  bool get isFull => players.length >= maxPlayers;
  bool get canStart => players.length >= maxPlayers; // Wait for all required players
  bool get isActive => status == GameStatus.inProgress;
  bool get isWaiting => status == GameStatus.waitingForPlayers;
  
  GameSessionModel addPlayer(PlayerInGame player) {
    if (isFull) return this;
    
    final updatedPlayers = [...players, player];
    final updatedPlayerIds = [...playerIds, player.userId];
    
    return copyWith(
      players: updatedPlayers,
      playerIds: updatedPlayerIds,
    );
  }

  GameSessionModel startGame() {
    return copyWith(
      status: GameStatus.inProgress,
      startedAt: DateTime.now(),
    );
  }

  GameSessionModel markForTeacherReview({String? winnerId}) {
    return copyWith(
      status: GameStatus.pendingTeacherReview,
      winnerId: winnerId,
    );
  }
  
  GameSessionModel endGame({String? winnerId}) {
    return copyWith(
      status: GameStatus.completed,
      endedAt: DateTime.now(),
      winnerId: winnerId,
    );
  }

  @override
  String toString() {
    return 'GameSessionModel(gameId: $gameId, gameName: $gameName, players: ${players.length}/$maxPlayers, status: $status)';
  }
}

class PlayerInGame {
  final String userId;
  final String displayName;
  final String emailAddress;
  final DateTime joinedAt;
  final int wordsRead;
  final bool isReady;
  final int? playerColor;
  final String? avatarUrl;

  PlayerInGame({
    required this.userId,
    required this.displayName,
    required this.emailAddress,
    required this.joinedAt,
    this.wordsRead = 0,
    this.isReady = false,
    this.playerColor,
    this.avatarUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'emailAddress': emailAddress,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'wordsRead': wordsRead,
      'isReady': isReady,
      'playerColor': playerColor,
      'avatarUrl': avatarUrl,
    };
  }

  // Convert to JSON (for session storage - uses ISO strings instead of Timestamps)
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'emailAddress': emailAddress,
      'joinedAt': joinedAt.toIso8601String(),
      'wordsRead': wordsRead,
      'isReady': isReady,
      'playerColor': playerColor,
      'avatarUrl': avatarUrl,
    };
  }

  // Create from JSON (for session storage - handles ISO strings)
  factory PlayerInGame.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return PlayerInGame(
      userId: json['userId'] ?? '',
      displayName: json['displayName'] ?? '',
      emailAddress: json['emailAddress'] ?? '',
      joinedAt: parseDateTime(json['joinedAt']),
      wordsRead: (json['wordsRead'] ?? 0).toInt(),
      isReady: json['isReady'] ?? false,
      playerColor: json['playerColor'],
      avatarUrl: json['avatarUrl'],
    );
  }

  factory PlayerInGame.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.parse(value);
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return PlayerInGame(
      userId: map['userId'] ?? '',
      displayName: map['displayName'] ?? '',
      emailAddress: map['emailAddress'] ?? '',
      joinedAt: parseDateTime(map['joinedAt']),
      wordsRead: (map['wordsRead'] ?? 0).toInt(),
      isReady: map['isReady'] ?? false,
      playerColor: map['playerColor'],
      avatarUrl: map['avatarUrl'],
    );
  }

  PlayerInGame copyWith({
    String? userId,
    String? displayName,
    String? emailAddress,
    DateTime? joinedAt,
    int? wordsRead,
    bool? isReady,
    int? playerColor,
    String? avatarUrl,
  }) {
    return PlayerInGame(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      emailAddress: emailAddress ?? this.emailAddress,
      joinedAt: joinedAt ?? this.joinedAt,
      wordsRead: wordsRead ?? this.wordsRead,
      isReady: isReady ?? this.isReady,
      playerColor: playerColor ?? this.playerColor,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

enum GameStatus {
  waitingForPlayers,
  inProgress,
  pendingTeacherReview, // Winner detected, waiting for teacher to review and update stats
  completed,
  cancelled,
}