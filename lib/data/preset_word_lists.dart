class PresetWordLists {
  static const List<String> kindergartenWords = [
    'a', 'i', 'in', 'is', 'it', 'to', 'the', 'and', 'me', 'my',
    'not', 'am', 'on', 'we', 'can', 'for', 'you', 'go', 'up', 'at',
    'did', 'down', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
    'nine', 'ten', 'away', 'big', 'come', 'find', 'funny', 'help', 'here', 'jump',
    'little', 'look', 'make', 'play', 'run', 'said', 'see', 'where', 'but', 'blue',
    'red', 'green', 'black', 'brown', 'orange', 'pink', 'white', 'purple', 'yellow', 'that',
    'came', 'went', 'saw', 'all', 'are', 'be', 'do', 'eat', 'have',
    'he', 'she', 'under', 'too', 'this', 'get', 'good', 'ate', 'into', 'like',
    'must', 'new', 'no', 'now', 'our', 'out', 'please', 'pretty', 'ran', 'ride',
    'say', 'so', 'soon', 'there', 'they', 'want', 'was', 'well', 'what', 'who',
    'will', 'with', 'yea'
  ];

  static const List<String> firstGradeWords = [
    'the', 'a', 'and', 'is', 'his', 'of', 'as', 'has', 'to', 'into',
    'we', 'he', 'she', 'be', 'me', 'for', 'or', 'you', 'your', 'I',
    'they', 'was', 'one', 'said', 'from', 'have', 'do', 'does', 'were', 'are',
    'who', 'what', 'when', 'where', 'there', 'here', 'why', 'by', 'my', 'try',
    'put', 'two', 'too', 'very', 'also', 'some', 'come', 'would', 'could', 'should',
    'her', 'over', 'number', 'say', 'says', 'see', 'between', 'each', 'any', 'many',
    'how', 'now', 'down', 'out', 'about', 'our', 'friend', 'other', 'another', 'none',
    'nothing', 'people', 'month', 'little', 'been', 'own', 'want', 'mr', 'mrs', 'work',
    'word', 'write', 'being', 'their', 'first', 'look', 'good', 'new', 'water', 'called',
    'day', 'may', 'way'
  ];

  static const List<String> secondGradeWords = [
    'pull', 'shall', 'full', 'both', 'talk', 'walk', 'goes', 'pretty', 'done', 'again',
    'please', 'sure', 'animal', 'used', 'use', 'against', 'knew', 'know', 'always', 'often',
    'once', 'house', 'only', 'move', 'right', 'place', 'together', 'eight', 'large', 'change',
    'city', 'every', 'family', 'night', 'carry', 'something', 'world', 'answer', 'different', 'picture',
    'learn', 'earth', 'father', 'brother', 'mother', 'great', 'country', 'away', 'America', 'school',
    'thought', 'won', 'whose', 'son', 'breakfast', 'head', 'ready', 'easy', 'favorite', 'ocean',
    'Monday', 'Tuesday', 'cousin', 'lose', 'tomorrow', 'beautiful', 'Wednesday', 'Thursday', 'Saturday', 'bought',
    'brought', 'piece', 'January', 'February', 'enough', 'July', 'special', 'December', 'August', 'laugh',
    'daughter', 'trouble', 'couple', 'young'
  ];

  static List<List<String>> getRandomWordsForGrid(String gradeLevel, {int totalWords = 36}) {
    List<String> sourceWords;
    
    switch (gradeLevel.toLowerCase()) {
      case 'kindergarten':
      case 'k':
        sourceWords = List.from(kindergartenWords);
        break;
      case 'first':
      case '1':
      case '1st':
        sourceWords = List.from(firstGradeWords);
        break;
      case 'second':
      case '2':
      case '2nd':
        sourceWords = List.from(secondGradeWords);
        break;
      default:
        sourceWords = List.from(kindergartenWords);
    }
    
    sourceWords.shuffle();
    
    final selectedWords = sourceWords.take(totalWords).toList();
    
    final List<List<String>> grid = [];
    for (int i = 0; i < 6; i++) {
      final row = <String>[];
      for (int j = 0; j < 6; j++) {
        final index = i * 6 + j;
        if (index < selectedWords.length) {
          row.add(selectedWords[index]);
        }
      }
      if (row.isNotEmpty) {
        grid.add(row);
      }
    }
    
    return grid;
  }

  static String getGradeLevelDescription(String gradeLevel) {
    switch (gradeLevel.toLowerCase()) {
      case 'kindergarten':
      case 'k':
        return 'Kindergarten Sight Words';
      case 'first':
      case '1':
      case '1st':
        return 'First Grade Trick Words';
      case 'second':
      case '2':
      case '2nd':
        return 'Second Grade Trick Words';
      default:
        return 'Word List';
    }
  }
}