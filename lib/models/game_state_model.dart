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

class GameStateModel {
  final String gameId;
  final int currentDiceValue;
  final String? currentPlayerId; // Player who rolled the dice
  final Map<String, Set<String>> playerCompletedCells; // playerId -> set of cell keys
  final Map<String, int> playerScores; // playerId -> score
  final DateTime? lastDiceRoll;
  final bool isRolling;
  final String? currentTurnPlayerId; // For turn-based mode
  final bool simultaneousPlay; // true = both play at same time, false = turn-based
  final Set<String> contestedCells; // cells that are currently contested (both players selected)
  final Map<String, PronunciationAttempt> pendingPronunciations; // cellKey -> pronunciation attempt

  GameStateModel({
    required this.gameId,
    this.currentDiceValue = 1,
    this.currentPlayerId,
    Map<String, Set<String>>? playerCompletedCells,
    Map<String, int>? playerScores,
    this.lastDiceRoll,
    this.isRolling = false,
    this.currentTurnPlayerId,
    this.simultaneousPlay = true, // Default to simultaneous play
    Set<String>? contestedCells,
    Map<String, PronunciationAttempt>? pendingPronunciations,
  }) : playerCompletedCells = playerCompletedCells ?? {},
       playerScores = playerScores ?? {},
       contestedCells = contestedCells ?? {},
       pendingPronunciations = pendingPronunciations ?? {};

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

    return GameStateModel(
      gameId: map['gameId'] ?? '',
      currentDiceValue: map['currentDiceValue'] ?? 1,
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
  }) {
    return GameStateModel(
      gameId: gameId ?? this.gameId,
      currentDiceValue: currentDiceValue ?? this.currentDiceValue,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      playerCompletedCells: playerCompletedCells ?? this.playerCompletedCells,
      playerScores: playerScores ?? this.playerScores,
      lastDiceRoll: lastDiceRoll ?? this.lastDiceRoll,
      isRolling: isRolling ?? this.isRolling,
      currentTurnPlayerId: currentTurnPlayerId ?? this.currentTurnPlayerId,
      simultaneousPlay: simultaneousPlay ?? this.simultaneousPlay,
      contestedCells: contestedCells ?? this.contestedCells,
      pendingPronunciations: pendingPronunciations ?? this.pendingPronunciations,
    );
  }

  // Helper method to add a completed cell for a player
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
      // Square is owned by another player - this becomes a contested square
      updatedCells[playerId] = Set<String>.from(updatedCells[playerId]!)..add(cellKey);
      updatedContestedCells.add(cellKey);
      // No score change yet - contested squares don't give points
    } else {
      // Square is free - player takes it normally
      updatedCells[playerId] = Set<String>.from(updatedCells[playerId]!)..add(cellKey);
      updatedScores[playerId] = (updatedScores[playerId] ?? 0) + 1;
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
      // Start with first player
      return copyWith(currentTurnPlayerId: playerIds.first);
    }
    
    final currentIndex = playerIds.indexOf(currentTurnPlayerId!);
    if (currentIndex == -1) {
      // Current player not found, start with first player
      return copyWith(currentTurnPlayerId: playerIds.first);
    }
    
    // Switch to next player (wrap around if at end)
    final nextIndex = (currentIndex + 1) % playerIds.length;
    return copyWith(currentTurnPlayerId: playerIds[nextIndex]);
  }
}