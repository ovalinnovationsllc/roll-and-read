import 'package:cloud_firestore/cloud_firestore.dart';

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
  }) : playerCompletedCells = playerCompletedCells ?? {},
       playerScores = playerScores ?? {};

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
    };
  }

  factory GameStateModel.fromMap(Map<String, dynamic> map) {
    Map<String, Set<String>> completedCells = {};
    if (map['playerCompletedCells'] != null) {
      (map['playerCompletedCells'] as Map<String, dynamic>).forEach((key, value) {
        completedCells[key] = Set<String>.from(value as List);
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
    );
  }

  // Helper method to add a completed cell for a player
  GameStateModel markCellCompleted(String playerId, String cellKey) {
    final updatedCells = Map<String, Set<String>>.from(playerCompletedCells);
    if (!updatedCells.containsKey(playerId)) {
      updatedCells[playerId] = {};
    }
    updatedCells[playerId] = Set<String>.from(updatedCells[playerId]!)..add(cellKey);
    
    final updatedScores = Map<String, int>.from(playerScores);
    updatedScores[playerId] = (updatedScores[playerId] ?? 0) + 1;
    
    return copyWith(
      playerCompletedCells: updatedCells,
      playerScores: updatedScores,
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
}