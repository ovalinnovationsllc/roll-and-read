import 'package:cloud_firestore/cloud_firestore.dart';

class WordListModel {
  final String id;
  final String prompt;
  final String difficulty;
  final List<List<String>> wordGrid; // 6x6 grid of words
  final DateTime createdAt;
  final String? createdBy; // Admin user ID who generated this
  final int timesUsed; // Track how often this list is used

  WordListModel({
    required this.id,
    required this.prompt,
    required this.difficulty,
    required this.wordGrid,
    required this.createdAt,
    this.createdBy,
    this.timesUsed = 0,
  });

  // Create a new word list
  factory WordListModel.create({
    required String prompt,
    required String difficulty,
    required List<List<String>> wordGrid,
    String? createdBy,
  }) {
    return WordListModel(
      id: '', // Will be set by Firestore
      prompt: prompt,
      difficulty: difficulty,
      wordGrid: wordGrid,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      timesUsed: 0,
    );
  }

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    // Flatten the 2D array for Firestore (which doesn't support nested arrays)
    List<String> flatWordGrid = [];
    for (var row in wordGrid) {
      flatWordGrid.addAll(row);
    }
    
    return {
      'prompt': prompt,
      'difficulty': difficulty,
      'wordGrid': flatWordGrid, // Store as flat array
      'wordGridRows': 6, // Store dimensions for reconstruction
      'wordGridCols': 6,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'timesUsed': timesUsed,
    };
  }

  // Create from Map (database retrieval)
  factory WordListModel.fromMap(String id, Map<String, dynamic> map) {
    List<List<String>> parseWordGrid(dynamic gridData, Map<String, dynamic> map) {
      if (gridData == null || gridData is! List) return [];
      
      try {
        // Reconstruct 2D array from flat array
        final flatGrid = List<String>.from(gridData);
        final rows = (map['wordGridRows'] ?? 6) as int;
        final cols = (map['wordGridCols'] ?? 6) as int;
        
        if (flatGrid.length != rows * cols) {
          return []; // Return empty if size doesn't match
        }
        
        List<List<String>> grid = [];
        for (int i = 0; i < rows; i++) {
          final startIdx = i * cols;
          final endIdx = startIdx + cols;
          grid.add(flatGrid.sublist(startIdx, endIdx));
        }
        return grid;
      } catch (e) {
        return [];
      }
    }

    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return WordListModel(
      id: id,
      prompt: map['prompt'] ?? '',
      difficulty: map['difficulty'] ?? 'medium',
      wordGrid: parseWordGrid(map['wordGrid'], map),
      createdAt: parseDateTime(map['createdAt']),
      createdBy: map['createdBy'],
      timesUsed: (map['timesUsed'] ?? 0).toInt(),
    );
  }

  // Copy with method for updates
  WordListModel copyWith({
    String? id,
    String? prompt,
    String? difficulty,
    List<List<String>>? wordGrid,
    DateTime? createdAt,
    String? createdBy,
    int? timesUsed,
  }) {
    return WordListModel(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      difficulty: difficulty ?? this.difficulty,
      wordGrid: wordGrid ?? this.wordGrid,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      timesUsed: timesUsed ?? this.timesUsed,
    );
  }

  @override
  String toString() {
    return 'WordListModel(id: $id, prompt: $prompt, difficulty: $difficulty, timesUsed: $timesUsed)';
  }
}