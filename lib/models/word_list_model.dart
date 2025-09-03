import 'package:cloud_firestore/cloud_firestore.dart';

// Grade level constants matching the UI dropdown
class GradeLevel {
  static const String PRE_K = 'PRE_K';
  static const String KINDERGARTEN = 'KINDERGARTEN';
  static const String ELEMENTARY = 'ELEMENTARY';
  static const String MIDDLE_SCHOOL = 'MIDDLE_SCHOOL';
  static const String HIGH_SCHOOL = 'HIGH_SCHOOL';
  
  static const List<String> all = [
    PRE_K,
    KINDERGARTEN,
    ELEMENTARY,
    MIDDLE_SCHOOL,
    HIGH_SCHOOL,
  ];
  
  static String getDisplayName(String grade) {
    switch (grade) {
      case PRE_K:
        return 'Pre-K';
      case KINDERGARTEN:
        return 'Kindergarten';
      case ELEMENTARY:
        return 'Elementary';
      case MIDDLE_SCHOOL:
        return 'Middle School';
      case HIGH_SCHOOL:
        return 'High School';
      default:
        return grade;
    }
  }
}

class WordListModel {
  final String id;
  final String prompt;
  final String difficulty;
  final List<List<String>> wordGrid; // 6x6 grid of words
  final DateTime createdAt;
  final String? createdBy; // Admin user ID who generated this
  final int timesUsed; // Track how often this list is used
  final DateTime? lastUsed; // Track when last used
  final List<String> tags; // Categories/topics for organization
  final bool isPublic; // Allow sharing between teachers
  final String? grade; // Grade level (PRE_K, KINDERGARTEN, ELEMENTARY, MIDDLE_SCHOOL, HIGH_SCHOOL)
  final String? subject; // Subject area (reading, phonics, vocabulary, etc.)

  WordListModel({
    required this.id,
    required this.prompt,
    required this.difficulty,
    required this.wordGrid,
    required this.createdAt,
    this.createdBy,
    this.timesUsed = 0,
    this.lastUsed,
    List<String>? tags,
    this.isPublic = false,
    this.grade,
    this.subject,
  }) : tags = tags ?? [];

  // Create a new word list
  factory WordListModel.create({
    required String prompt,
    required String difficulty,
    required List<List<String>> wordGrid,
    String? createdBy,
    List<String>? tags,
    bool isPublic = false,
    String? grade,
    String? subject,
  }) {
    // Auto-generate tags from prompt if not provided
    final autoTags = tags ?? _extractTagsFromPrompt(prompt);
    
    // Auto-infer grade level from difficulty if not provided
    final inferredGrade = grade ?? _inferGradeFromDifficulty(difficulty);
    
    return WordListModel(
      id: '', // Will be set by Firestore
      prompt: prompt,
      difficulty: difficulty,
      wordGrid: wordGrid,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      timesUsed: 0,
      lastUsed: DateTime.now(),
      tags: autoTags,
      isPublic: isPublic,
      grade: inferredGrade,
      subject: subject ?? _inferSubjectFromPrompt(prompt),
    );
  }
  
  // Helper to infer grade level from difficulty
  static String? _inferGradeFromDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'preschool':
      case 'pre-k':
      case 'prek':
        return GradeLevel.PRE_K;
      case 'kindergarten':
      case 'k':
        return GradeLevel.KINDERGARTEN;
      case 'elementary':
      case 'easy':
        return GradeLevel.ELEMENTARY;
      case 'middle':
      case 'medium':
      case 'intermediate':
        return GradeLevel.MIDDLE_SCHOOL;
      case 'high':
      case 'hard':
      case 'advanced':
        return GradeLevel.HIGH_SCHOOL;
      default:
        return GradeLevel.ELEMENTARY; // Default to elementary
    }
  }
  
  // Helper to extract tags from prompt
  static List<String> _extractTagsFromPrompt(String prompt) {
    final tags = <String>[];
    final lowerPrompt = prompt.toLowerCase();
    
    // Check for common themes
    if (lowerPrompt.contains('animal')) tags.add('animals');
    if (lowerPrompt.contains('phonics') || lowerPrompt.contains('sound')) tags.add('phonics');
    if (lowerPrompt.contains('sight word')) tags.add('sight-words');
    if (lowerPrompt.contains('math') || lowerPrompt.contains('number')) tags.add('math');
    if (lowerPrompt.contains('science')) tags.add('science');
    if (lowerPrompt.contains('social') || lowerPrompt.contains('history')) tags.add('social-studies');
    if (lowerPrompt.contains('vocab')) tags.add('vocabulary');
    if (lowerPrompt.contains('rhym')) tags.add('rhyming');
    if (lowerPrompt.contains('spell')) tags.add('spelling');
    
    return tags;
  }
  
  // Helper to infer subject from prompt
  static String? _inferSubjectFromPrompt(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    
    if (lowerPrompt.contains('phonics') || lowerPrompt.contains('sound')) return 'phonics';
    if (lowerPrompt.contains('sight word')) return 'sight-words';
    if (lowerPrompt.contains('math') || lowerPrompt.contains('number')) return 'math';
    if (lowerPrompt.contains('science')) return 'science';
    if (lowerPrompt.contains('social') || lowerPrompt.contains('history')) return 'social-studies';
    if (lowerPrompt.contains('vocab')) return 'vocabulary';
    if (lowerPrompt.contains('spell')) return 'spelling';
    
    return 'reading'; // Default subject
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
      'lastUsed': lastUsed != null ? Timestamp.fromDate(lastUsed!) : null,
      'tags': tags,
      'isPublic': isPublic,
      'grade': grade,
      'subject': subject,
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
      lastUsed: map['lastUsed'] != null ? parseDateTime(map['lastUsed']) : null,
      tags: map['tags'] != null ? List<String>.from(map['tags']) : [],
      isPublic: map['isPublic'] ?? false,
      grade: map['grade'],
      subject: map['subject'],
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
    DateTime? lastUsed,
    List<String>? tags,
    bool? isPublic,
    String? grade,
    String? subject,
  }) {
    return WordListModel(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      difficulty: difficulty ?? this.difficulty,
      wordGrid: wordGrid ?? this.wordGrid,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      timesUsed: timesUsed ?? this.timesUsed,
      lastUsed: lastUsed ?? this.lastUsed,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
      grade: grade ?? this.grade,
      subject: subject ?? this.subject,
    );
  }

  @override
  String toString() {
    return 'WordListModel(id: $id, prompt: $prompt, difficulty: $difficulty, timesUsed: $timesUsed)';
  }
}