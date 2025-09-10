import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for teacher-created custom word lists
class CustomWordListModel {
  final String id;
  final String title; // Teacher's custom title
  final List<String> words;
  final String createdBy; // Teacher ID
  final DateTime createdAt;
  final DateTime? lastUsed;
  final int timesUsed;
  final String? gradeLevel; // Optional
  final String? description; // Optional teacher notes
  final bool isShared; // Can other teachers use it

  CustomWordListModel({
    required this.id,
    required this.title,
    required this.words,
    required this.createdBy,
    required this.createdAt,
    this.lastUsed,
    this.timesUsed = 0,
    this.gradeLevel,
    this.description,
    this.isShared = false,
  });

  // Create a new custom word list
  factory CustomWordListModel.create({
    required String title,
    required List<String> words,
    required String createdBy,
    String? gradeLevel,
    String? description,
    bool isShared = false,
  }) {
    return CustomWordListModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      words: words,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      gradeLevel: gradeLevel,
      description: description,
      isShared: isShared,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'words': words,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUsed': lastUsed != null ? Timestamp.fromDate(lastUsed!) : null,
      'timesUsed': timesUsed,
      'gradeLevel': gradeLevel,
      'description': description,
      'isShared': isShared,
    };
  }

  // Create from Firestore document
  factory CustomWordListModel.fromMap(String id, Map<String, dynamic> map) {
    return CustomWordListModel(
      id: id,
      title: map['title'] ?? 'Untitled',
      words: List<String>.from(map['words'] ?? []),
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastUsed: map['lastUsed'] != null 
          ? (map['lastUsed'] as Timestamp).toDate() 
          : null,
      timesUsed: map['timesUsed'] ?? 0,
      gradeLevel: map['gradeLevel'],
      description: map['description'],
      isShared: map['isShared'] ?? false,
    );
  }

  // Copy with updates
  CustomWordListModel copyWith({
    String? id,
    String? title,
    List<String>? words,
    String? createdBy,
    DateTime? createdAt,
    DateTime? lastUsed,
    int? timesUsed,
    String? gradeLevel,
    String? description,
    bool? isShared,
  }) {
    return CustomWordListModel(
      id: id ?? this.id,
      title: title ?? this.title,
      words: words ?? this.words,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      timesUsed: timesUsed ?? this.timesUsed,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      description: description ?? this.description,
      isShared: isShared ?? this.isShared,
    );
  }

  // Create a 6x6 grid from the word list
  List<List<String>> toGrid() {
    const totalCells = 36; // 6x6 grid
    final selectedWords = <String>[];
    
    if (words.isEmpty) {
      // Handle empty word list case
      return List.generate(6, (_) => List.generate(6, (_) => 'WORD'));
    }
    
    final availableWords = List<String>.from(words);
    final random = Random();
    
    // Add all words first if we have enough
    if (availableWords.length >= totalCells) {
      availableWords.shuffle();
      selectedWords.addAll(availableWords.take(totalCells));
    } else {
      // Add all available words first
      selectedWords.addAll(availableWords);
      
      // Randomly duplicate words from the same list to reach 36 total
      while (selectedWords.length < totalCells) {
        final randomWord = availableWords[random.nextInt(availableWords.length)];
        selectedWords.add(randomWord);
      }
    }
    
    // Final shuffle to mix originals with duplicates
    selectedWords.shuffle();
    
    // Create 6x6 grid
    final List<List<String>> grid = [];
    for (int i = 0; i < 6; i++) {
      final row = <String>[];
      for (int j = 0; j < 6; j++) {
        final index = i * 6 + j;
        row.add(selectedWords[index]);
      }
      grid.add(row);
    }
    
    return grid;
  }
}