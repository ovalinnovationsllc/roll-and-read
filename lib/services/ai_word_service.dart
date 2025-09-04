import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import 'demo_ai_service.dart';
import 'content_filter_service.dart';

class AIWordService {
  // Using Google Gemini API - free tier with 15 requests/minute
  static const String _geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';
  
  // Get API key from secure configuration
  static String get _geminiApiKey => AppConfig.geminiApiKey;
  
  // Get demo mode setting from configuration
  static bool get _useDemoMode => AppConfig.useDemoMode;
  
  /// Check if prompt contains inappropriate content
  static bool _isInappropriatePrompt(String prompt) {
    return ContentFilterService.hasInappropriateContent(prompt);
  }
  
  /// Filter inappropriate words from AI response
  static List<String> _filterInappropriateWords(List<String> words) {
    return ContentFilterService.filterWords(words);
  }
  
  /// Get a safe default grid for when content is filtered
  static List<List<String>> _getDefaultSafeGrid() {
    return ContentFilterService.getSafeWordGrid();
  }
  
  /// Generate a 6x6 grid of words based on Mrs. Elson's prompt
  /// Returns a 6x6 matrix of words suitable for reading practice
  static Future<List<List<String>>> generateWordGrid({
    required String prompt,
    String difficulty = 'elementary',
  }) async {
    try {
      // Check for inappropriate prompt
      if (_isInappropriatePrompt(prompt)) {
        // Return safe default grid instead of processing inappropriate content
        return _getDefaultSafeGrid();
      }
      
      // Use demo service for now (can be switched to real AI later)
      if (_useDemoMode) {
        return await DemoAIService.generateWordGrid(
          prompt: prompt,
          difficulty: difficulty,
        );
      }
      
      // Real AI service (when API key is available)
      final aiPrompt = _buildGeminiPrompt(prompt, difficulty);
      final response = await _callGemini(aiPrompt);
      final grid = _parseWordGrid(response);
      
      // Filter each row for inappropriate words
      final safeGrid = <List<String>>[];
      for (final row in grid) {
        final safeRow = _filterInappropriateWords(row);
        // Ensure we have 6 words per row, pad with safe defaults if needed
        if (safeRow.length < 6) {
          final replacements = ContentFilterService.getSafeReplacements(6 - safeRow.length);
          safeRow.addAll(replacements);
        }
        safeGrid.add(safeRow.take(6).toList());
      }
      
      return safeGrid;
      
    } catch (e) {
      
      // Fallback to default words if AI fails
      return _getFallbackGrid();
    }
  }
  
  /// Generate words for a specific column (when dice is rolled)
  static Future<List<String>> generateColumnWords({
    required String prompt,
    required int column,
    String difficulty = 'elementary',
  }) async {
    try {
      // Check for inappropriate prompt
      if (_isInappropriatePrompt(prompt)) {
        // Return safe default column
        return _getFallbackColumn(column);
      }
      
      // Use demo service for now
      if (_useDemoMode) {
        return await DemoAIService.generateColumnWords(
          prompt: prompt,
          column: column,
          difficulty: difficulty,
        );
      }
      
      // Real AI service
      final aiPrompt = _buildGeminiColumnPrompt(prompt, column, difficulty);
      final response = await _callGemini(aiPrompt);
      var words = _parseWordList(response, 6); // Return 6 words for the column
      
      // Filter inappropriate words
      words = _filterInappropriateWords(words);
      
      // Ensure we have 6 words, pad with safe defaults if needed
      if (words.length < 6) {
        final replacements = ContentFilterService.getSafeReplacements(6 - words.length);
        words.addAll(replacements);
      }
      
      return words.take(6).toList();
      
    } catch (e) {
      return _getFallbackColumn(column);
    }
  }
  
  /// Build the main prompt for Gemini word generation
  static String _buildGeminiPrompt(String prompt, String difficulty) {
    // Check if the prompt specifies a word pattern
    final lowerPrompt = prompt.toLowerCase();
    String patternInstructions = '';
    
    // Check for CVC pattern requests
    if (lowerPrompt.contains('cvc')) {
      patternInstructions += '- MUST be three-letter CVC (consonant-vowel-consonant) words\n';
    }
    
    // Check for ending pattern (e.g., "ending in -it", "ending with at")
    final endingPattern = RegExp(r'ending (?:in|with) ["\x27]?(-?\w+)["\x27]?').firstMatch(lowerPrompt);
    if (endingPattern != null) {
      final ending = endingPattern.group(1)?.replaceAll('-', '');
      patternInstructions += '- ALL words MUST end with "$ending"\n';
      patternInstructions += '- CRITICAL: Every single word must have "$ending" as its ending\n';
    }
    
    // Check for rhyming pattern
    if (lowerPrompt.contains('rhym')) {
      final rhymePattern = RegExp(r'rhym\w* (?:with |words |-)(\w+)').firstMatch(lowerPrompt);
      if (rhymePattern != null) {
        final rhyme = rhymePattern.group(1);
        patternInstructions += '- ALL words MUST rhyme with "$rhyme"\n';
      }
    }
    
    return '''
Create a reading game word grid for $difficulty students.
Mrs. Elson's topic: "$prompt"

Generate exactly 36 educational words that are:
- Appropriate for $difficulty reading level
- Related to: "$prompt"
$patternInstructions- Simple, clear, and safe for children
- Varied but thematically connected

${patternInstructions.isNotEmpty ? 'CRITICAL REQUIREMENT: You MUST follow the pattern constraints above. Double-check that EVERY word meets the specified pattern.\n' : ''}
IMPORTANT: Respond with exactly 36 words separated by commas only:
word1, word2, word3, word4, word5, word6, word7, word8, word9, word10, word11, word12, word13, word14, word15, word16, word17, word18, word19, word20, word21, word22, word23, word24, word25, word26, word27, word28, word29, word30, word31, word32, word33, word34, word35, word36

No extra text, just the 36 comma-separated words.
''';
  }
  
  /// Build prompt for generating specific column words with Gemini
  static String _buildGeminiColumnPrompt(String prompt, int column, String difficulty) {
    // Check if the prompt specifies a word pattern
    final lowerPrompt = prompt.toLowerCase();
    String patternInstructions = '';
    
    // Check for CVC pattern requests
    if (lowerPrompt.contains('cvc')) {
      patternInstructions += '- MUST be three-letter CVC (consonant-vowel-consonant) words\n';
    }
    
    // Check for ending pattern (e.g., "ending in -it", "ending with at")
    final endingPattern = RegExp(r'ending (?:in|with) ["\x27]?(-?\w+)["\x27]?').firstMatch(lowerPrompt);
    if (endingPattern != null) {
      final ending = endingPattern.group(1)?.replaceAll('-', '');
      patternInstructions += '- ALL words MUST end with "$ending"\n';
      patternInstructions += '- CRITICAL: Every single word must have "$ending" as its ending\n';
    }
    
    // Check for rhyming pattern
    if (lowerPrompt.contains('rhym')) {
      final rhymePattern = RegExp(r'rhym\w* (?:with |words |-)(\w+)').firstMatch(lowerPrompt);
      if (rhymePattern != null) {
        final rhyme = rhymePattern.group(1);
        patternInstructions += '- ALL words MUST rhyme with "$rhyme"\n';
      }
    }
    
    return '''
Create 6 reading words for $difficulty students.
Topic: "$prompt" (Column $column)

Generate exactly 6 educational words that are:
- Appropriate for $difficulty reading level  
- Related to: "$prompt"
$patternInstructions- Simple, clear, and safe for children
- Thematically connected

${patternInstructions.isNotEmpty ? 'CRITICAL REQUIREMENT: You MUST follow the pattern constraints above. Double-check that EVERY word meets the specified pattern.\n' : ''}
IMPORTANT: Respond with exactly 6 words separated by commas only:
word1, word2, word3, word4, word5, word6

No extra text, just the 6 comma-separated words.
''';
  }
  
  /// Make the actual API call to Gemini
  static Future<String> _callGemini(String prompt) async {
    final url = '$_geminiUrl?key=$_geminiApiKey';
    
    final headers = {
      'Content-Type': 'application/json',
    };
    
    final body = json.encode({
      'contents': [
        {
          'parts': [
            {
              'text': prompt,
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 200,
        'topP': 0.8,
        'topK': 10,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
      ],
    });
    
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: body,
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
    } else {
      throw Exception('Gemini API call failed: ${response.statusCode} - ${response.body}');
    }
  }
  
  /// Parse AI response into a 6x6 grid
  static List<List<String>> _parseWordGrid(String aiResponse) {
    // Clean and split the response
    final words = aiResponse
        .replaceAll('\n', ' ')
        .split(',')
        .map((word) => word.trim().toLowerCase())
        .where((word) => word.isNotEmpty)
        .toList();
    
    // Ensure we have exactly 36 words
    while (words.length < 36) {
      words.add('word${words.length + 1}');
    }
    if (words.length > 36) {
      words.removeRange(36, words.length);
    }
    
    // Convert to 6x6 grid
    final grid = <List<String>>[];
    for (int row = 0; row < 6; row++) {
      final startIndex = row * 6;
      grid.add(words.sublist(startIndex, startIndex + 6));
    }
    
    return grid;
  }
  
  /// Parse AI response into a word list
  static List<String> _parseWordList(String aiResponse, int count) {
    final words = aiResponse
        .replaceAll('\n', ' ')
        .split(',')
        .map((word) => word.trim().toLowerCase())
        .where((word) => word.isNotEmpty)
        .toList();
    
    // Ensure we have the right number of words
    while (words.length < count) {
      words.add('word${words.length + 1}');
    }
    if (words.length > count) {
      words.removeRange(count, words.length);
    }
    
    return words;
  }
  
  /// Fallback grid when AI service is unavailable
  static List<List<String>> _getFallbackGrid() {
    return [
      ['cat', 'dog', 'pig', 'cow', 'hen', 'fox'],
      ['run', 'hop', 'sit', 'jump', 'walk', 'skip'], 
      ['red', 'blue', 'green', 'pink', 'yellow', 'white'],
      ['mom', 'dad', 'sister', 'brother', 'baby', 'family'],
      ['one', 'two', 'three', 'four', 'five', 'six'],
      ['sun', 'moon', 'star', 'cloud', 'rain', 'snow'],
    ];
  }
  
  /// Fallback column words
  static List<String> _getFallbackColumn(int column) {
    final fallbackGrid = _getFallbackGrid();
    return fallbackGrid.map((row) => row[column - 1]).toList();
  }
  
  /// Enable/disable demo mode - useful for testing
  static void setDemoMode(bool enabled) {
    // Note: This would require making _useDemoMode non-const
    // For now, change the constant at the top of the file
  }
  
  /// Get API status information
  static Map<String, dynamic> getAPIStatus() {
    return {
      'demoMode': _useDemoMode,
      'apiType': 'Google Gemini',
      'hasApiKey': AppConfig.hasApiKey,
      'freeRequests': '15 per minute',
      'model': 'gemini-1.5-flash-latest',
    };
  }
  
  /// Validate that words are appropriate for the target audience
  static bool _validateWords(List<String> words) {
    // Add validation logic here
    // Check for inappropriate content, difficulty level, etc.
    for (final word in words) {
      if (word.length > 10 || word.contains(RegExp(r'[^a-zA-Z]'))) {
        return false;
      }
    }
    return true;
  }
  
  /// Get available difficulty levels
  static List<String> getDifficultyLevels() {
    return [
      'pre-k',
      'kindergarten', 
      'elementary',
      'middle-school',
      'high-school',
    ];
  }
  
  /// Get suggested prompt templates for Mrs. Elson
  static List<String> getPromptTemplates() {
    return [
      'Animals and their sounds',
      'Colors and shapes',
      'Family members',
      'Food and cooking',
      'Weather and seasons',
      'Transportation vehicles',
      'Body parts',
      'School supplies',
      'Sports and activities', 
      'Numbers and counting',
      'Feelings and emotions',
      'Community helpers',
      'Long vowel sounds (a, e, i, o, u)',
      'Short vowel sounds',
      'Words ending in -ing',
      'Words that rhyme with "cat"',
      'Science vocabulary: space',
      'Math terms for beginners',
      'Healthy foods',
      'Safety words',
    ];
  }
}