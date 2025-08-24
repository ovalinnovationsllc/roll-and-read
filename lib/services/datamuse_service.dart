import 'dart:convert';
import 'package:http/http.dart' as http;

class DatamuseService {
  static const String _baseUrl = 'https://api.datamuse.com';

  /// Fetches words with long u sound patterns from Datamuse API
  /// Long u patterns include: oo, ue, ew, u_e
  static Future<List<String>> fetchLongUWords() async {
    List<String> allWords = [];
    
    // Different long u sound patterns
    List<String> patterns = [
      'oo',  // moon, spoon, soon
      'ue',  // blue, true, glue
      'ew',  // new, few, drew
      'ute', // cute, flute, mute
      'ube', // cube, tube
      'use', // fuse, muse
      'ule', // rule, mule
      'une', // tune, dune, June
    ];
    
    try {
      // Fetch words for each pattern
      for (String pattern in patterns) {
        final response = await http.get(
          Uri.parse('$_baseUrl/words?sp=*$pattern*&max=50'),
        );
        
        if (response.statusCode == 200) {
          List<dynamic> data = json.decode(response.body);
          
          // Extract words and filter for appropriate ones
          for (var item in data) {
            String word = item['word']?.toString() ?? '';
            
            // Filter for simple, child-appropriate words (3-6 letters)
            if (word.length >= 3 && 
                word.length <= 6 && 
                !word.contains('-') &&
                !word.contains(' ') &&
                RegExp(r'^[a-z]+$').hasMatch(word)) {
              allWords.add(word);
            }
          }
        }
      }
      
      // Remove duplicates and shuffle
      allWords = allWords.toSet().toList();
      allWords.shuffle();
      
      // Ensure we have at least 36 words (6x6 grid)
      // If not enough, add some hardcoded long u words
      List<String> fallbackWords = [
        'moon', 'soon', 'noon', 'spoon', 'zoom', 'room',
        'blue', 'true', 'glue', 'clue', 'due', 'sue',
        'new', 'few', 'drew', 'grew', 'flew', 'knew',
        'cute', 'mute', 'flute', 'chute', 'brute', 'jute',
        'cube', 'tube', 'rube', 'lube', 'pube', 'dube',
        'tune', 'dune', 'june', 'prune', 'rune', 'lune'
      ];
      
      // Add fallback words if needed
      for (String word in fallbackWords) {
        if (allWords.length >= 36) break;
        if (!allWords.contains(word)) {
          allWords.add(word);
        }
      }
      
      // Limit to 36 words for the grid
      if (allWords.length > 36) {
        allWords = allWords.take(36).toList();
      }
      
      return allWords;
      
    } catch (e) {
      print('Error fetching words: $e');
      
      // Return fallback words on error
      return [
        'moon', 'soon', 'noon', 'spoon', 'zoom', 'room',
        'blue', 'true', 'glue', 'clue', 'due', 'sue',
        'new', 'few', 'drew', 'grew', 'flew', 'knew',
        'cute', 'mute', 'flute', 'chute', 'brute', 'jute',
        'cube', 'tube', 'rube', 'lube', 'use', 'fuse',
        'tune', 'dune', 'june', 'prune', 'rune', 'rule'
      ];
    }
  }

  /// Organizes words into a 6x6 grid
  static List<List<String>> organizeIntoGrid(List<String> words) {
    List<List<String>> grid = [];
    
    // Ensure we have exactly 36 words
    while (words.length < 36) {
      words.add('word');
    }
    
    // Create 6 rows of 6 columns
    for (int i = 0; i < 6; i++) {
      List<String> row = [];
      for (int j = 0; j < 6; j++) {
        int index = i * 6 + j;
        if (index < words.length) {
          row.add(words[index]);
        } else {
          row.add('');
        }
      }
      grid.add(row);
    }
    
    return grid;
  }
}