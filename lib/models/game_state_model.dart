import 'package:cloud_firestore/cloud_firestore.dart';

class PronunciationAttempt {
  final String playerId;
  final String playerName;
  final String cellKey;
  final String word;
  final DateTime startTime;
  
  PronunciationAttempt({
    required this.playerId,
    required this.playerName,
    required this.cellKey,
    required this.word,
    required this.startTime,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'cellKey': cellKey,
      'word': word,
      'startTime': Timestamp.fromDate(startTime),
    };
  }
  
  factory PronunciationAttempt.fromMap(Map<String, dynamic> map) {
    return PronunciationAttempt(
      playerId: map['playerId'] ?? '',
      playerName: map['playerName'] ?? '',
      cellKey: map['cellKey'] ?? '',
      word: map['word'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
    );
  }
}

class PronunciationLogEntry {
  final String playerId;
  final String playerName;
  final String cellKey;
  final String word;
  final DateTime attemptTime;
  final DateTime resolvedTime;
  final bool approved; // true = approved, false = rejected
  final String? previousOwnerId; // ID of player who owned the cell before (for steals)
  final String? previousOwnerName; // Name of player who owned the cell before
  
  PronunciationLogEntry({
    required this.playerId,
    required this.playerName,
    required this.cellKey,
    required this.word,
    required this.attemptTime,
    required this.resolvedTime,
    required this.approved,
    this.previousOwnerId,
    this.previousOwnerName,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'cellKey': cellKey,
      'word': word,
      'attemptTime': Timestamp.fromDate(attemptTime),
      'resolvedTime': Timestamp.fromDate(resolvedTime),
      'approved': approved,
      'previousOwnerId': previousOwnerId,
      'previousOwnerName': previousOwnerName,
    };
  }
  
  factory PronunciationLogEntry.fromMap(Map<String, dynamic> map) {
    return PronunciationLogEntry(
      playerId: map['playerId'] ?? '',
      playerName: map['playerName'] ?? '',
      cellKey: map['cellKey'] ?? '',
      word: map['word'] ?? '',
      attemptTime: (map['attemptTime'] as Timestamp).toDate(),
      resolvedTime: (map['resolvedTime'] as Timestamp).toDate(),
      approved: map['approved'] ?? false,
      previousOwnerId: map['previousOwnerId'],
      previousOwnerName: map['previousOwnerName'],
    );
  }
}

class GameStateModel {
  final String gameId;
  final int? currentDiceValue;
  final String? currentPlayerId; // Player who rolled the dice
  final Map<String, Set<String>> playerCompletedCells; // playerId -> set of cell keys
  final Map<String, int> playerScores; // playerId -> score
  final DateTime? lastDiceRoll;
  final bool isRolling;
  final String? currentTurnPlayerId; // For turn-based mode
  final bool simultaneousPlay; // true = both play at same time, false = turn-based
  final Set<String> contestedCells; // cells that are currently contested (both players selected)
  final Map<String, PronunciationAttempt> pendingPronunciations; // cellKey -> pronunciation attempt
  final List<PronunciationLogEntry> pronunciationLog; // completed pronunciation attempts (approved/rejected)

  GameStateModel({
    required this.gameId,
    this.currentDiceValue, // null means no dice rolled yet
    this.currentPlayerId,
    Map<String, Set<String>>? playerCompletedCells,
    Map<String, int>? playerScores,
    this.lastDiceRoll,
    this.isRolling = false,
    this.currentTurnPlayerId,
    this.simultaneousPlay = true, // Default to simultaneous play
    Set<String>? contestedCells,
    Map<String, PronunciationAttempt>? pendingPronunciations,
    List<PronunciationLogEntry>? pronunciationLog,
  }) : playerCompletedCells = playerCompletedCells ?? {},
       playerScores = playerScores ?? {},
       contestedCells = contestedCells ?? {},
       pendingPronunciations = pendingPronunciations ?? {},
       pronunciationLog = pronunciationLog ?? [];

  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'currentDiceValue': currentDiceValue,
      'currentPlayerId': currentPlayerId,
      'playerCompletedCells': playerCompletedCells.map(
        (key, value) => MapEntry(key, value.toList()),
      ),
      'playerScores': playerScores,
      'lastDiceRoll': lastDiceRoll != null ? Timestamp.fromDate(lastDiceRoll!) : null,
      'isRolling': isRolling,
      'currentTurnPlayerId': currentTurnPlayerId,
      'simultaneousPlay': simultaneousPlay,
      'contestedCells': contestedCells.toList(),
      'pendingPronunciations': pendingPronunciations.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'pronunciationLog': pronunciationLog.map((entry) => entry.toMap()).toList(),
    };
  }

  factory GameStateModel.fromMap(Map<String, dynamic> map) {
    Map<String, Set<String>> completedCells = {};
    if (map['playerCompletedCells'] != null) {
      (map['playerCompletedCells'] as Map<String, dynamic>).forEach((key, value) {
        completedCells[key] = Set<String>.from(value as List);
      });
    }

    Map<String, PronunciationAttempt> pronunciations = {};
    if (map['pendingPronunciations'] != null) {
      (map['pendingPronunciations'] as Map<String, dynamic>).forEach((key, value) {
        pronunciations[key] = PronunciationAttempt.fromMap(value as Map<String, dynamic>);
      });
    }

    List<PronunciationLogEntry> logEntries = [];
    if (map['pronunciationLog'] != null) {
      logEntries = (map['pronunciationLog'] as List)
          .map((entry) => PronunciationLogEntry.fromMap(entry as Map<String, dynamic>))
          .toList();
    }

    return GameStateModel(
      gameId: map['gameId'] ?? '',
      currentDiceValue: map['currentDiceValue'],
      currentPlayerId: map['currentPlayerId'],
      playerCompletedCells: completedCells,
      playerScores: Map<String, int>.from(map['playerScores'] ?? {}),
      lastDiceRoll: map['lastDiceRoll'] != null 
        ? (map['lastDiceRoll'] as Timestamp).toDate() 
        : null,
      isRolling: map['isRolling'] ?? false,
      currentTurnPlayerId: map['currentTurnPlayerId'],
      simultaneousPlay: map['simultaneousPlay'] ?? true,
      contestedCells: Set<String>.from(map['contestedCells'] ?? []),
      pendingPronunciations: pronunciations,
      pronunciationLog: logEntries,
    );
  }

  GameStateModel copyWith({
    String? gameId,
    int? currentDiceValue,
    String? currentPlayerId,
    Map<String, Set<String>>? playerCompletedCells,
    Map<String, int>? playerScores,
    DateTime? lastDiceRoll,
    bool? isRolling,
    String? currentTurnPlayerId,
    bool? simultaneousPlay,
    Set<String>? contestedCells,
    Map<String, PronunciationAttempt>? pendingPronunciations,
    List<PronunciationLogEntry>? pronunciationLog,
    bool resetDiceValue = false, // Explicit flag to reset dice to null
  }) {
    return GameStateModel(
      gameId: gameId ?? this.gameId,
      currentDiceValue: resetDiceValue ? null : (currentDiceValue ?? this.currentDiceValue),
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      playerCompletedCells: playerCompletedCells ?? this.playerCompletedCells,
      playerScores: playerScores ?? this.playerScores,
      lastDiceRoll: lastDiceRoll ?? this.lastDiceRoll,
      isRolling: isRolling ?? this.isRolling,
      currentTurnPlayerId: currentTurnPlayerId ?? this.currentTurnPlayerId,
      simultaneousPlay: simultaneousPlay ?? this.simultaneousPlay,
      contestedCells: contestedCells ?? this.contestedCells,
      pendingPronunciations: pendingPronunciations ?? this.pendingPronunciations,
      pronunciationLog: pronunciationLog ?? this.pronunciationLog,
    );
  }

  // Helper method to add a completed cell for a player (handles stealing)
  GameStateModel markCellCompleted(String playerId, String cellKey) {
    final updatedCells = Map<String, Set<String>>.from(playerCompletedCells);
    final updatedScores = Map<String, int>.from(playerScores);
    final updatedContestedCells = Set<String>.from(contestedCells);
    
    if (!updatedCells.containsKey(playerId)) {
      updatedCells[playerId] = {};
    }
    
    // Check if any other player already owns this cell
    String? currentOwner;
    for (String otherPlayerId in updatedCells.keys) {
      if (otherPlayerId != playerId && updatedCells[otherPlayerId]!.contains(cellKey)) {
        currentOwner = otherPlayerId;
        break;
      }
    }
    
    if (currentOwner != null) {
      // STEALING: Square is owned by another player
      
      // Remove cell from original owner's collection  
      updatedCells[currentOwner] = Set<String>.from(updatedCells[currentOwner]!)..remove(cellKey);
      
      // Add cell to stealer's collection (complete transfer of ownership)
      updatedCells[playerId] = Set<String>.from(updatedCells[playerId]!)..add(cellKey);
      
      // Remove from contested cells (cell now has single owner)
      updatedContestedCells.remove(cellKey);
      
      // Update scores: +1 for stealer, -1 for original owner
      updatedScores[playerId] = (updatedScores[playerId] ?? 0) + 1;
      updatedScores[currentOwner] = (updatedScores[currentOwner] ?? 0) - 1;
      if (updatedScores[currentOwner]! < 0) updatedScores[currentOwner] = 0;
    } else {
      // Square is free - player takes it normally
      updatedCells[playerId] = Set<String>.from(updatedCells[playerId]!)..add(cellKey);
      updatedScores[playerId] = (updatedScores[playerId] ?? 0) + 1;
      print('✅ CLAIM: $playerId claimed free cell $cellKey, score=${updatedScores[playerId]}');
    }
    
    return copyWith(
      playerCompletedCells: updatedCells,
      playerScores: updatedScores,
      contestedCells: updatedContestedCells,
    );
  }
  
  // Helper method to resolve a contested cell (player gets it right and steals it)
  GameStateModel resolveContestedCell(String winningPlayerId, String cellKey) {
    final updatedCells = Map<String, Set<String>>.from(playerCompletedCells);
    final updatedScores = Map<String, int>.from(playerScores);
    final updatedContestedCells = Set<String>.from(contestedCells);
    
    // Remove from contested cells
    updatedContestedCells.remove(cellKey);
    
    // Remove cell from all other players and reduce their scores
    for (String playerId in updatedCells.keys) {
      if (playerId != winningPlayerId && updatedCells[playerId]!.contains(cellKey)) {
        updatedCells[playerId] = Set<String>.from(updatedCells[playerId]!)..remove(cellKey);
        updatedScores[playerId] = (updatedScores[playerId] ?? 0) - 1;
        if (updatedScores[playerId]! < 0) updatedScores[playerId] = 0;
      }
    }
    
    // Give the cell to the winning player and increase their score
    if (!updatedCells.containsKey(winningPlayerId)) {
      updatedCells[winningPlayerId] = {};
    }
    updatedCells[winningPlayerId] = Set<String>.from(updatedCells[winningPlayerId]!)..add(cellKey);
    updatedScores[winningPlayerId] = (updatedScores[winningPlayerId] ?? 0) + 1;
    
    return copyWith(
      playerCompletedCells: updatedCells,
      playerScores: updatedScores,
      contestedCells: updatedContestedCells,
    );
  }

  // Helper method to unmark a cell for a player
  GameStateModel unmarkCell(String playerId, String cellKey) {
    final updatedCells = Map<String, Set<String>>.from(playerCompletedCells);
    if (updatedCells.containsKey(playerId)) {
      updatedCells[playerId] = Set<String>.from(updatedCells[playerId]!)..remove(cellKey);
      
      final updatedScores = Map<String, int>.from(playerScores);
      updatedScores[playerId] = (updatedScores[playerId] ?? 0) - 1;
      if (updatedScores[playerId]! < 0) updatedScores[playerId] = 0;
      
      return copyWith(
        playerCompletedCells: updatedCells,
        playerScores: updatedScores,
      );
    }
    return this;
  }

  // Helper to get cells completed by a specific player
  Set<String> getPlayerCompletedCells(String playerId) {
    return playerCompletedCells[playerId] ?? {};
  }

  // Helper to get player score
  int getPlayerScore(String playerId) {
    return playerScores[playerId] ?? 0;
  }
  
  // Helper to check if a cell is contested
  bool isCellContested(String cellKey) {
    return contestedCells.contains(cellKey);
  }
  
  // Helper to get the owner of a cell (returns null if contested or unowned)
  String? getCellOwner(String cellKey) {
    if (contestedCells.contains(cellKey)) {
      return null; // Contested - no single owner
    }
    
    for (String playerId in playerCompletedCells.keys) {
      if (playerCompletedCells[playerId]!.contains(cellKey)) {
        return playerId;
      }
    }
    return null; // Unowned
  }
  
  // Helper method to start a pronunciation attempt
  GameStateModel startPronunciationAttempt({
    required String playerId,
    required String playerName,
    required String cellKey,
    required String word,
  }) {
    final updatedPronunciations = Map<String, PronunciationAttempt>.from(pendingPronunciations);
    
    updatedPronunciations[cellKey] = PronunciationAttempt(
      playerId: playerId,
      playerName: playerName,
      cellKey: cellKey,
      word: word,
      startTime: DateTime.now(),
    );
    
    return copyWith(pendingPronunciations: updatedPronunciations);
  }
  
  // Helper method to complete a pronunciation attempt (teacher approves)
  GameStateModel approvePronunciation(String cellKey) {
    if (!pendingPronunciations.containsKey(cellKey)) {
      return this; // No pending pronunciation
    }
    
    final attempt = pendingPronunciations[cellKey]!;
    
    // Remove the pending pronunciation first
    final updatedPronunciations = Map<String, PronunciationAttempt>.from(pendingPronunciations);
    updatedPronunciations.remove(cellKey);
    
    // Find out who (if anyone) currently owns this cell, excluding the challenger
    String? victimPlayerId;
    for (String playerId in playerCompletedCells.keys) {
      if (playerId != attempt.playerId && playerCompletedCells[playerId]!.contains(cellKey)) {
        victimPlayerId = playerId;
        break;
      }
    }
    
    if (victimPlayerId != null) {
      // This is a steal - transfer ownership from victim to challenger
      final updatedCells = Map<String, Set<String>>.from(playerCompletedCells);
      final updatedScores = Map<String, int>.from(playerScores);
      final updatedContestedCells = Set<String>.from(contestedCells);
      
      // Remove cell from victim
      updatedCells[victimPlayerId] = Set<String>.from(updatedCells[victimPlayerId]!)..remove(cellKey);
      updatedScores[victimPlayerId] = (updatedScores[victimPlayerId] ?? 0) - 1;
      if (updatedScores[victimPlayerId]! < 0) updatedScores[victimPlayerId] = 0;
      
      // Give cell to challenger (ensure challenger has a set first)
      if (!updatedCells.containsKey(attempt.playerId)) {
        updatedCells[attempt.playerId] = {};
      }
      updatedCells[attempt.playerId] = Set<String>.from(updatedCells[attempt.playerId]!)..add(cellKey);
      updatedScores[attempt.playerId] = (updatedScores[attempt.playerId] ?? 0) + 1;
      
      // Remove from contested cells (no longer contested)
      updatedContestedCells.remove(cellKey);
      
      return copyWith(
        pendingPronunciations: updatedPronunciations,
        playerCompletedCells: updatedCells,
        playerScores: updatedScores,
        contestedCells: updatedContestedCells,
      );
    } else {
      // This is a normal claim of an unowned cell
      return copyWith(pendingPronunciations: updatedPronunciations)
          .markCellCompleted(attempt.playerId, cellKey);
    }
  }
  
  // Helper method to reject a pronunciation attempt (teacher rejects or times out)
  GameStateModel rejectPronunciation(String cellKey) {
    final updatedPronunciations = Map<String, PronunciationAttempt>.from(pendingPronunciations);
    updatedPronunciations.remove(cellKey);
    
    return copyWith(pendingPronunciations: updatedPronunciations);
  }
  
  // Helper to check if a cell has a pending pronunciation
  bool hasPendingPronunciation(String cellKey) {
    return pendingPronunciations.containsKey(cellKey);
  }
  
  // Helper to get pending pronunciation for a cell
  PronunciationAttempt? getPendingPronunciation(String cellKey) {
    return pendingPronunciations[cellKey];
  }
  
  // Helper to switch to next player's turn
  GameStateModel switchToNextTurn(List<String> playerIds) {
    if (simultaneousPlay || playerIds.isEmpty) {
      return this; // No turn switching in simultaneous mode
    }
    
    if (currentTurnPlayerId == null) {
      // Start with first player, reset dice for fresh turn
      return copyWith(
        currentTurnPlayerId: playerIds.first,
        currentPlayerId: null,
        lastDiceRoll: null,
        resetDiceValue: true, // Reset dice value for fresh turn
      );
    }
    
    final currentIndex = playerIds.indexOf(currentTurnPlayerId!);
    if (currentIndex == -1) {
      // Current player not found, start with first player
      return copyWith(
        currentTurnPlayerId: playerIds.first,
        currentPlayerId: null,
        lastDiceRoll: null,
        resetDiceValue: true, // Reset dice value for fresh turn
      );
    }
    
    // Switch to next player (wrap around if at end)
    final nextIndex = (currentIndex + 1) % playerIds.length;
    return copyWith(
      currentTurnPlayerId: playerIds[nextIndex],
      currentPlayerId: null,
      lastDiceRoll: null,
      resetDiceValue: true, // Reset dice value for fresh turn
    );
  }
  
  // Helper method to check if a player has won (6 in a row horizontally, vertically, or diagonally)
  String? checkForWinner() {
    for (String playerId in playerCompletedCells.keys) {
      if (_hasPlayerWon(playerId)) {
        return playerId;
      }
    }
    return null;
  }
  
  bool _hasPlayerWon(String playerId) {
    final cells = playerCompletedCells[playerId] ?? {};
    print('DEBUG: Checking win condition for $playerId with ${cells.length} cells: $cells');
    if (cells.length < 6) return false; // Need at least 6 cells to win
    
    // Convert cell keys to coordinates
    final coordinates = <List<int>>[];
    for (String cellKey in cells) {
      final parts = cellKey.split(','); // Changed from '-' to ',' to match actual format
      if (parts.length == 2) {
        final row = int.tryParse(parts[0]);
        final col = int.tryParse(parts[1]);
        if (row != null && col != null) {
          coordinates.add([row, col]);
        }
      }
    }
    
    
    // Check all possible lines of 6
    final hasWon = _checkLines(coordinates);
    return hasWon;
  }
  
  bool _checkLines(List<List<int>> coordinates) {
    // Check horizontal lines (same row)
    for (int row = 0; row < 6; row++) {
      int count = 0;
      for (int col = 0; col < 6; col++) {
        if (coordinates.any((coord) => coord[0] == row && coord[1] == col)) {
          count++;
        }
      }
      if (count >= 6) return true;
    }
    
    // Check vertical lines (same column)
    for (int col = 0; col < 6; col++) {
      int count = 0;
      for (int row = 0; row < 6; row++) {
        if (coordinates.any((coord) => coord[0] == row && coord[1] == col)) {
          count++;
        }
      }
      if (count >= 6) return true;
    }
    
    // Check diagonal lines (top-left to bottom-right)
    // Main diagonal
    int count = 0;
    for (int i = 0; i < 6; i++) {
      if (coordinates.any((coord) => coord[0] == i && coord[1] == i)) {
        count++;
      } else {
        count = 0;
      }
      if (count >= 6) return true;
    }
    
    // Check diagonal lines (top-right to bottom-left)  
    // Anti-diagonal
    count = 0;
    for (int i = 0; i < 6; i++) {
      if (coordinates.any((coord) => coord[0] == i && coord[1] == (5 - i))) {
        count++;
      } else {
        count = 0;
      }
      if (count >= 6) return true;
    }
    
    return false;
  }
}
