import 'dart:io';

class UFLILessonLists {
  // Structure to hold lesson information
  static const Map<String, Map<String, String>> lessonCategories = {
    'kindergarten': {
      'title': 'UFLI Kindergarten Lessons',
      'description': 'Individual lesson-based word lists from UFLI Foundations Kindergarten',
    },
    'first_grade': {
      'title': 'UFLI First Grade Lessons', 
      'description': 'Individual lesson-based word lists from UFLI Foundations First Grade',
    },
    'second_grade': {
      'title': 'UFLI Second Grade Lessons',
      'description': 'Individual lesson-based word lists from UFLI Foundations Second Grade',
    },
  };

  // Get all available lesson files for a grade level
  static Future<List<String>> getAvailableLessons(String gradeLevel) async {
    final directory = Directory('lesson_lists/$gradeLevel');
    if (!await directory.exists()) return [];
    
    final files = await directory.list().where((entity) => 
      entity is File && entity.path.endsWith('.txt')).toList();
    
    return files.map((file) => 
      file.path.split('/').last.replaceAll('.txt', '')).toList()..sort();
  }

  // Read words from a specific lesson file
  static Future<List<String>> getLessonWords(String gradeLevel, String lessonName) async {
    final file = File('lesson_lists/$gradeLevel/$lessonName.txt');
    if (!await file.exists()) return [];
    
    final content = await file.readAsString();
    return content.trim().split('\n')
        .where((word) => word.isNotEmpty)
        .map((word) => word.trim())
        .toList();
  }

  // Create a 6x6 grid from lesson words
  static Future<List<List<String>>> getLessonGrid(String gradeLevel, String lessonName) async {
    final words = await getLessonWords(gradeLevel, lessonName);
    if (words.isEmpty) return [];

    // Ensure we have exactly 36 words for the grid
    final gridWords = <String>[];
    
    // If we have 36 or more words, take first 36
    if (words.length >= 36) {
      gridWords.addAll(words.take(36));
    } else {
      // If we have fewer than 36, repeat words to fill grid
      gridWords.addAll(words);
      while (gridWords.length < 36) {
        for (final word in words) {
          if (gridWords.length >= 36) break;
          gridWords.add(word);
        }
      }
    }

    // Shuffle the words for variety
    gridWords.shuffle();

    // Create 6x6 grid
    final List<List<String>> grid = [];
    for (int i = 0; i < 6; i++) {
      final row = <String>[];
      for (int j = 0; j < 6; j++) {
        final index = i * 6 + j;
        row.add(gridWords[index]);
      }
      grid.add(row);
    }

    return grid;
  }

  // Get human-readable lesson title
  static String getLessonTitle(String lessonFileName) {
    // Convert filename like "Lesson_35c_short_a_advanced_review" to readable title
    return lessonFileName
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'\b\w'), (match) => match.group(0)!.toUpperCase());
  }

  // Get lesson description based on lesson content
  static String getLessonDescription(String lessonFileName) {
    final title = getLessonTitle(lessonFileName);
    
    if (title.contains('Short A')) return 'Practice with short A vowel sounds';
    if (title.contains('Short I')) return 'Practice with short I vowel sounds';  
    if (title.contains('Short O')) return 'Practice with short O vowel sounds';
    if (title.contains('Short U')) return 'Practice with short U vowel sounds';
    if (title.contains('Short E')) return 'Practice with short E vowel sounds';
    if (title.contains('Digraphs')) return 'Two-letter combinations making single sounds';
    if (title.contains('Consonant')) return 'Consonant blends and combinations';
    if (title.contains('Vowel')) return 'Vowel patterns and combinations';
    if (title.contains('VCe')) return 'Vowel-consonant-e (magic e) patterns';
    if (title.contains('ing')) return 'Words ending with -ing suffix';
    if (title.contains('ed')) return 'Words ending with -ed suffix';
    if (title.contains('er')) return 'Words with -er patterns';
    if (title.contains('Compound')) return 'Compound word practice';
    
    return 'UFLI phonics lesson practice';
  }

  // Get all lessons for dropdown/selection
  static Future<List<Map<String, dynamic>>> getAllLessonsForGrade(String gradeLevel) async {
    final lessons = await getAvailableLessons(gradeLevel);
    return lessons.map((lesson) => {
      'id': lesson,
      'title': getLessonTitle(lesson),
      'description': getLessonDescription(lesson),
      'gradeLevel': gradeLevel,
    }).toList();
  }

  // Check if lesson files are available
  static Future<bool> areLessonFilesAvailable() async {
    for (final grade in lessonCategories.keys) {
      final lessons = await getAvailableLessons(grade);
      if (lessons.isNotEmpty) return true;
    }
    return false;
  }

  // Get lesson statistics
  static Future<Map<String, int>> getLessonStats() async {
    final stats = <String, int>{};
    
    for (final grade in lessonCategories.keys) {
      final lessons = await getAvailableLessons(grade);
      stats[grade] = lessons.length;
    }
    
    return stats;
  }
}