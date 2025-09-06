import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import 'demo_ai_service.dart';
import 'content_filter_service.dart';
import 'datamuse_service.dart';
import 'word_generation_logger.dart';

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
    String? gameId,
    String? gameName,
  }) async {
    final startTime = DateTime.now();
    List<String> servicesUsed = [];
    Map<String, int> wordCounts = {};
    List<String> allGeneratedWords = [];
    String finalServiceUsed = '';
    bool success = false;
    String? errorMessage;
    
    try {
      // Check for inappropriate prompt
      if (_isInappropriatePrompt(prompt)) {
        finalServiceUsed = 'CONTENT_FILTERED';
        // Log the filtering for analytics
        await WordGenerationLogger.logWordGeneration(
          prompt: prompt,
          difficulty: difficulty,
          services: ['content_filter'],
          wordCounts: {'fallback': 36},
          sampleWords: _getDefaultSafeGrid().expand((row) => row).toList(),
          finalService: finalServiceUsed,
          success: true,
          gameId: gameId,
          gameName: gameName,
          additionalData: {'reason': 'inappropriate_content'},
        );
        
        return _getDefaultSafeGrid();
      }
      
      // Try Datamuse first for pattern-based prompts
      List<String> datamuseWords = [];
      bool usedDatamuse = false;
      
      if (DatamuseService.canHandlePrompt(prompt)) {
        print('═══════════════════════════════════════════════════════════════');
        print('🎯 WORD GENERATION REQUEST');
        print('📝 Prompt: "$prompt"');
        print('🔍 Datamuse can handle this prompt - trying Datamuse first');
        
        // Log pattern detection
        await WordGenerationLogger.logPatternDetection(
          prompt: prompt,
          detectedPattern: DatamuseService.extractPattern(prompt),
          datamuseCanHandle: true,
          gameId: gameId,
        );
        
        final datamuseStartTime = DateTime.now();
        datamuseWords = await DatamuseService.generateWordsFromPrompt(prompt);
        usedDatamuse = datamuseWords.isNotEmpty;
        
        // Log Datamuse performance
        await WordGenerationLogger.logServicePerformance(
          service: 'datamuse',
          prompt: prompt,
          responseTime: DateTime.now().difference(datamuseStartTime),
          wordsGenerated: datamuseWords.length,
          success: datamuseWords.isNotEmpty,
          gameId: gameId,
        );
        
        if (usedDatamuse) {
          servicesUsed.add('datamuse');
          wordCounts['datamuse'] = datamuseWords.length;
          allGeneratedWords.addAll(datamuseWords);
        }
        
        if (datamuseWords.length >= 36) {
          print('✅ SUCCESS: Datamuse provided ${datamuseWords.length} words');
          print('📊 Using: DATAMUSE ONLY');
          print('🎲 Sample words: ${datamuseWords.take(10).join(", ")}...');
          print('═══════════════════════════════════════════════════════════════');
          
          finalServiceUsed = 'DATAMUSE ONLY';
          success = true;
          final finalWords = datamuseWords.take(36).toList();
          
          // Log final result
          await WordGenerationLogger.logWordGeneration(
            prompt: prompt,
            difficulty: difficulty,
            services: servicesUsed,
            wordCounts: wordCounts,
            sampleWords: finalWords,
            finalService: finalServiceUsed,
            success: success,
            gameId: gameId,
            gameName: gameName,
          );
          
          return DatamuseService.organizeIntoGrid(finalWords);
        } else if (datamuseWords.isNotEmpty) {
          print('⚠️  Datamuse provided only ${datamuseWords.length} words');
          print('🔄 Will combine with AI service to get remaining words');
        } else {
          print('❌ Datamuse returned no words for this prompt');
        }
      } else {
        print('═══════════════════════════════════════════════════════════════');
        print('🎯 WORD GENERATION REQUEST');
        print('📝 Prompt: "$prompt"');
        print('🤖 This prompt is better suited for AI generation');
        
        // Log pattern detection
        await WordGenerationLogger.logPatternDetection(
          prompt: prompt,
          datamuseCanHandle: false,
          gameId: gameId,
        );
      }
      
      // Generate AI words (Demo or Gemini)
      List<String> aiWords = [];
      final aiStartTime = DateTime.now();
      
      if (_useDemoMode) {
        print('🤖 AI Service: Using DEMO mode');
        final demoGrid = await DemoAIService.generateWordGrid(
          prompt: prompt,
          difficulty: difficulty,
        );
        aiWords = demoGrid.expand((row) => row).toList();
        print('✅ SUCCESS: Demo AI provided ${aiWords.length} words');
        print('🎲 Sample words: ${aiWords.take(10).join(", ")}...');
        
        // Log Demo AI performance
        await WordGenerationLogger.logServicePerformance(
          service: 'demo_ai',
          prompt: prompt,
          responseTime: DateTime.now().difference(aiStartTime),
          wordsGenerated: aiWords.length,
          success: aiWords.isNotEmpty,
          gameId: gameId,
        );
        
        servicesUsed.add('demo_ai');
        wordCounts['demo_ai'] = aiWords.length;
        
      } else {
        print('🤖 AI Service: Using REAL GEMINI mode');
        
        // Real AI service (when API key is available)
        final aiPrompt = _buildGeminiPrompt(prompt, difficulty);
        print('📤 Gemini prompt: $aiPrompt');
        
        try {
          final response = await _callGemini(aiPrompt);
          print('📥 Gemini response: $response');
          
          // Check if we need to validate ending patterns
          String? requiredEnding;
          final lowerPrompt = prompt.toLowerCase();
          final endingPattern = RegExp(r'(?:ending|end|ends|that end) (?:in|with) ["\x27]?(-?\w+)["\x27]?').firstMatch(lowerPrompt);
          if (endingPattern != null) {
            requiredEnding = endingPattern.group(1)?.replaceAll('-', '');
            print('🎯 Detected ending pattern: "$requiredEnding" from prompt: "$prompt"');
          } else {
            print('🎯 No ending pattern detected in prompt: "$prompt"');
          }
          
          // Check for word length requirements
          int? requiredLength;
          final lengthPattern = RegExp(r'(\d+)\s*letter\s*words?').firstMatch(lowerPrompt);
          if (lengthPattern != null) {
            requiredLength = int.tryParse(lengthPattern.group(1) ?? '');
            print('🎯 Detected word length requirement: $requiredLength letters');
          }
          
          final grid = _parseWordGrid(response, requiredEnding: requiredEnding, requiredLength: requiredLength, originalPrompt: prompt);
          aiWords = grid.expand((row) => row).toList();
          print('✅ SUCCESS: Gemini provided ${aiWords.length} words after validation');
          print('🎲 Sample words: ${aiWords.take(10).join(", ")}...');
          
          // Log Gemini performance
          await WordGenerationLogger.logServicePerformance(
            service: 'gemini',
            prompt: prompt,
            responseTime: DateTime.now().difference(aiStartTime),
            wordsGenerated: aiWords.length,
            success: aiWords.isNotEmpty,
            gameId: gameId,
          );
          
          servicesUsed.add('gemini');
          wordCounts['gemini'] = aiWords.length;
          
        } catch (e) {
          // Log Gemini failure
          await WordGenerationLogger.logServicePerformance(
            service: 'gemini',
            prompt: prompt,
            responseTime: DateTime.now().difference(aiStartTime),
            wordsGenerated: 0,
            success: false,
            error: e.toString(),
            gameId: gameId,
          );
          
          print('❌ Gemini API error: $e');
          aiWords = [];
        }
      }
      
      if (aiWords.isNotEmpty) {
        allGeneratedWords.addAll(aiWords.where((word) => !allGeneratedWords.contains(word)));
      }
      
      // Combine Datamuse and AI words if both were used
      List<String> finalWords = [];
      if (datamuseWords.isNotEmpty && aiWords.isNotEmpty) {
        print('🔄 COMBINING RESULTS:');
        print('   📊 Datamuse words: ${datamuseWords.length}');
        print('   📊 AI words: ${aiWords.length}');
        
        finalWords.addAll(datamuseWords);
        // Add AI words to fill the remaining slots
        for (final word in aiWords) {
          if (!finalWords.contains(word) && finalWords.length < 36) {
            finalWords.add(word);
          }
        }
        
        finalServiceUsed = 'DATAMUSE + ${_useDemoMode ? "DEMO AI" : "GEMINI AI"}';
        print('📊 Using: $finalServiceUsed');
        print('📊 Final word count: ${finalWords.length}');
        print('🎲 Final sample: ${finalWords.take(10).join(", ")}...');
        
      } else if (datamuseWords.isNotEmpty) {
        finalWords = datamuseWords;
        finalServiceUsed = 'DATAMUSE ONLY';
        print('📊 Using: $finalServiceUsed');
        
      } else if (aiWords.isNotEmpty) {
        finalWords = aiWords;
        finalServiceUsed = '${_useDemoMode ? "DEMO AI" : "GEMINI AI"} ONLY';
        print('📊 Using: $finalServiceUsed');
        
      } else {
        print('❌ ERROR: No words generated from any service');
        finalServiceUsed = 'FALLBACK GRID';
        print('📊 Using: $finalServiceUsed');
        finalWords = _getFallbackGrid().expand((row) => row).toList();
        servicesUsed.add('fallback');
        wordCounts['fallback'] = 36;
      }
      
      success = finalWords.isNotEmpty;
      print('═══════════════════════════════════════════════════════════════');
      
      // Convert to grid format
      final gridWords = finalWords.take(36).toList();
      while (gridWords.length < 36) {
        gridWords.add('word${gridWords.length + 1}');
      }
      
      // Organize into 6x6 grid
      final grid = <List<String>>[];
      for (int row = 0; row < 6; row++) {
        final startIndex = row * 6;
        grid.add(gridWords.sublist(startIndex, startIndex + 6));
      }
      
      // Filter each row for inappropriate words
      final safeGrid = <List<String>>[];
      List<String> filteredWords = [];
      for (final row in grid) {
        final safeRow = _filterInappropriateWords(row);
        final originalLength = row.length;
        final filteredLength = safeRow.length;
        
        if (filteredLength < originalLength) {
          final removed = row.where((word) => !safeRow.contains(word)).toList();
          filteredWords.addAll(removed);
          
          // Log word filtering
          await WordGenerationLogger.logWordValidation(
            prompt: prompt,
            invalidWords: removed,
            reason: 'inappropriate_content',
            service: finalServiceUsed,
            gameId: gameId,
          );
        }
        
        // Ensure we have 6 words per row, pad with safe defaults if needed
        if (safeRow.length < 6) {
          final replacements = ContentFilterService.getSafeReplacements(6 - safeRow.length);
          safeRow.addAll(replacements);
        }
        safeGrid.add(safeRow.take(6).toList());
      }
      
      // Log final result to Firebase
      final finalSampleWords = safeGrid.expand((row) => row).toList();
      await WordGenerationLogger.logWordGeneration(
        prompt: prompt,
        difficulty: difficulty,
        services: servicesUsed,
        wordCounts: wordCounts,
        sampleWords: finalSampleWords,
        finalService: finalServiceUsed,
        success: success,
        gameId: gameId,
        gameName: gameName,
        additionalData: {
          'totalGenerationTime': DateTime.now().difference(startTime).inMilliseconds,
          'filteredWords': filteredWords.length,
          'combinedServices': servicesUsed.length > 1,
        },
      );
      
      return safeGrid;
      
    } catch (e) {
      print('═══════════════════════════════════════════════════════════════');
      print('❌ WORD GENERATION ERROR');
      print('📝 Prompt: "$prompt"');
      print('🔴 Error: $e');
      print('📊 Using: FALLBACK GRID (default words)');
      print('═══════════════════════════════════════════════════════════════');
      
      // Log the error to Firebase
      await WordGenerationLogger.logWordGeneration(
        prompt: prompt,
        difficulty: difficulty,
        services: servicesUsed.isEmpty ? ['error'] : servicesUsed,
        wordCounts: wordCounts.isEmpty ? {'error': 0} : wordCounts,
        sampleWords: _getFallbackGrid().expand((row) => row).toList(),
        finalService: 'FALLBACK GRID (ERROR)',
        success: false,
        error: e.toString(),
        gameId: gameId,
        gameName: gameName,
        additionalData: {
          'totalGenerationTime': DateTime.now().difference(startTime).inMilliseconds,
          'errorType': 'generation_failure',
        },
      );
      
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
    
    // Check for word length requirements
    final lengthPattern = RegExp(r'(\d+)\s*letter\s*words?').firstMatch(lowerPrompt);
    if (lengthPattern != null) {
      final length = lengthPattern.group(1);
      patternInstructions += '- MUST be exactly $length letters long\n';
      patternInstructions += '- CRITICAL: Every single word must have exactly $length letters\n';
    }
    
    // Check for CVC pattern requests
    if (lowerPrompt.contains('cvc')) {
      patternInstructions += '- MUST be three-letter CVC (consonant-vowel-consonant) words\n';
    }
    
    // Check for ending pattern (e.g., "ending in -it", "ending with at", "end in it")
    final endingPattern = RegExp(r'(?:ending|end|ends|that end) (?:in|with) ["\x27]?(-?\w+)["\x27]?').firstMatch(lowerPrompt);
    if (endingPattern != null) {
      final ending = endingPattern.group(1)?.replaceAll('-', '');
      patternInstructions += '- ALL words MUST end with the letters "$ending"\n';
      patternInstructions += '- CRITICAL: Every single word must have "$ending" as its final letters\n';
      patternInstructions += '- DO NOT include words ending with any other letters\n';
      patternInstructions += '- Examples of correct words ending in "$ending": ${_getExampleWords(ending ?? '')}\n';
    }
    
    // Check for rhyming pattern
    if (lowerPrompt.contains('rhym')) {
      final rhymePattern = RegExp(r'rhym\w* (?:with |words |-)(\w+)').firstMatch(lowerPrompt);
      if (rhymePattern != null) {
        final rhyme = rhymePattern.group(1);
        patternInstructions += '- ALL words MUST rhyme with "$rhyme"\n';
      }
    }
    
    // Check if we have an ending pattern and need to be extra explicit
    String endingEmphasis = '';
    if (patternInstructions.contains('MUST end with')) {
      final endingMatch = RegExp(r'MUST end with the letters "(\w+)"').firstMatch(patternInstructions);
      if (endingMatch != null) {
        final ending = endingMatch.group(1);
        endingEmphasis = '''

🚨 CRITICAL ENDING REQUIREMENT 🚨
- ALL 36 words MUST end with "$ending" 
- Examples of CORRECT words: ${_getExampleWords(ending ?? '')}
- DO NOT include "book", "tree", "happy", "blue" or any word not ending in "$ending"
- REJECT words like "rabbit" (ends in "bit" not "$ending")
- REJECT words like "credit" (ends in "dit" not "$ending") 
- Every single word must have "$ending" as the exact final letters
- Double-check EVERY word before including it
''';
      }
    }
    
    // Enhance basic prompts to be more specific
    String enhancedPrompt = _enhanceTeacherPrompt(prompt);
    String topicGuidance = _getTopicSpecificGuidance(enhancedPrompt);
    
    return '''
🚨 CHILDREN'S READING GAME - SIMPLE WORDS ONLY 🚨

CRITICAL: This is for children ages 5-12 with reading difficulties!

STRICT WORD REQUIREMENTS:
1. MAXIMUM 6 letters long (NO long words like "preeminent", "exceedingly")
2. ONLY words a kindergarten child would know and say
3. NO complex vocabulary, academic words, or adult words
4. Think: cat, dog, run, sun, big, red (YES) - NOT: eleemosynary, exceedingly (NO!)

BANNED WORD TYPES:
❌ Academic words: preeminent, eleemosynary, exceedingly, magnificent, extraordinary
❌ Complex adjectives: apprehensive, articulate, austere, abrasive, acquiesce
❌ Long words over 6 letters
❌ Words children don't use in daily conversation
❌ Sophisticated vocabulary
❌ Any word a 5-year-old wouldn't recognize

APPROVED SIMPLE WORDS ONLY:
✅ Animals: cat, dog, pig, cow, duck, hen, fox, bee
✅ Colors: red, blue, pink, green, yellow, brown, black, white  
✅ Actions: run, jump, sit, walk, play, eat, sleep, hop
✅ Body: eye, ear, nose, hand, foot, head, arm, leg
✅ Family: mom, dad, baby, sister, brother
✅ Food: apple, bread, milk, cake, egg, fish
✅ Home: bed, chair, table, door, window, house

$patternInstructions

$endingEmphasis

TASK: Generate exactly 36 words for "$prompt"
- Each word MAXIMUM 6 letters
- Each word must be something a kindergarten child says daily
- NO duplicates
- NO complex words
${patternInstructions.isNotEmpty ? '- EVERY word must match the pattern requirement' : ''}

RESPOND FORMAT: word1, word2, word3, word4, word5, word6, word7, word8, word9, word10, word11, word12, word13, word14, word15, word16, word17, word18, word19, word20, word21, word22, word23, word24, word25, word26, word27, word28, word29, word30, word31, word32, word33, word34, word35, word36

ONLY the 36 simple words - no extra text.
''';
  }
  
  /// Enhance basic teacher prompts to be more specific and get better results
  /// This app is for children with reading difficulties learning pronunciation/phonics
  static String _enhanceTeacherPrompt(String prompt) {
    final lowerPrompt = prompt.toLowerCase().trim();
    
    // PRIORITY 1: Check for phonics/pronunciation patterns first
    // This is the primary use case for children with reading difficulties
    
    // Short vowel sounds
    if (lowerPrompt.contains('short a')) {
      return 'words with short a sound like cat, bat, hat';
    }
    if (lowerPrompt.contains('short e')) {
      return 'words with short e sound like bed, red, net';
    }
    if (lowerPrompt.contains('short i')) {
      return 'words with short i sound like sit, hit, big';
    }
    if (lowerPrompt.contains('short o')) {
      return 'words with short o sound like hot, pot, dog';
    }
    if (lowerPrompt.contains('short u')) {
      return 'words with short u sound like cut, run, fun';
    }
    
    // Long vowel sounds - ONLY SIMPLE ELEMENTARY WORDS
    if (lowerPrompt.contains('long a')) {
      return 'SIMPLE words with long a sound: cake, name, play, day, way, say, make, take, lake, bake, game, same, late, gate, date, came, gave, save, wave, made - NO complex words like "apprehensive" or "articulate"';
    }
    if (lowerPrompt.contains('long e')) {
      return 'SIMPLE words with long e sound: tree, see, bee, free, green, three, sleep, keep, deep, seed, need, feed, meet, feet, week, sweet, beach, read, teach, eat - NO complex words';
    }
    if (lowerPrompt.contains('long i')) {
      return 'SIMPLE words with long i sound: bike, like, time, nine, fine, line, mine, five, hive, dive, ride, side, hide, wide, kite, white, nice, mice, rice, ice - NO complex words';
    }
    if (lowerPrompt.contains('long o')) {
      return 'SIMPLE words with long o sound: boat, goat, coat, road, toad, soap, hope, rope, note, vote, home, bone, cone, stone, phone, nose, rose, those, close, chose - NO complex words';
    }
    if (lowerPrompt.contains('long u')) {
      return 'SIMPLE words with long u sound: cute, tube, cube, huge, tune, June, dune, mule, rule, blue, glue, true, due, sue, new, few, grew, threw, knew, chew - NO complex words';
    }
    
    // Common phonics patterns
    if (lowerPrompt.contains('cvc')) {
      return 'simple consonant-vowel-consonant words like cat, dog, sun';
    }
    if (lowerPrompt.contains('cvce') || lowerPrompt.contains('magic e')) {
      return 'consonant-vowel-consonant-e words like cake, bike, home';
    }
    
    // Word families (very common for reading instruction)
    if (lowerPrompt.contains('-at') || lowerPrompt.contains('at family')) {
      return 'words ending in -at like cat, bat, hat, sat';
    }
    if (lowerPrompt.contains('-an') || lowerPrompt.contains('an family')) {
      return 'words ending in -an like can, man, ran, pan';
    }
    if (lowerPrompt.contains('-it') || lowerPrompt.contains('it family')) {
      return 'words ending in -it like sit, hit, bit, fit';
    }
    if (lowerPrompt.contains('-in') || lowerPrompt.contains('in family')) {
      return 'words ending in -in like pin, win, tin, bin';
    }
    if (lowerPrompt.contains('-ot') || lowerPrompt.contains('ot family')) {
      return 'words ending in -ot like pot, hot, dot, got';
    }
    if (lowerPrompt.contains('-un') || lowerPrompt.contains('un family')) {
      return 'words ending in -un like run, sun, fun, bun';
    }
    
    // Blends and digraphs
    if (lowerPrompt.contains('bl blend')) {
      return 'words starting with bl like blue, black, block';
    }
    if (lowerPrompt.contains('ch sound')) {
      return 'words with ch sound like chair, chip, much';
    }
    if (lowerPrompt.contains('sh sound')) {
      return 'words with sh sound like ship, shop, fish';
    }
    if (lowerPrompt.contains('th sound')) {
      return 'words with th sound like the, this, bath';
    }
    
    // Handle very basic prompts that teachers might use
    if (lowerPrompt == 'animals' || lowerPrompt == 'animal') {
      return 'farm animals and pets';
    }
    if (lowerPrompt == 'farm') {
      return 'farm animals';
    }
    if (lowerPrompt == 'food') {
      return 'common foods children eat';
    }
    if (lowerPrompt == 'colors' || lowerPrompt == 'color') {
      return 'basic color names';
    }
    if (lowerPrompt == 'shapes' || lowerPrompt == 'shape') {
      return 'basic geometric shapes';
    }
    if (lowerPrompt == 'transportation' || lowerPrompt == 'transport') {
      return 'vehicles and transportation';
    }
    if (lowerPrompt == 'body') {
      return 'body parts';
    }
    if (lowerPrompt == 'weather') {
      return 'weather conditions';
    }
    if (lowerPrompt == 'clothes' || lowerPrompt == 'clothing') {
      return 'clothing items children wear';
    }
    if (lowerPrompt == 'toys' || lowerPrompt == 'toy') {
      return 'children toys and games';
    }
    if (lowerPrompt == 'school') {
      return 'school supplies and classroom items';
    }
    if (lowerPrompt == 'home' || lowerPrompt == 'house') {
      return 'things found in a house';
    }
    if (lowerPrompt == 'family') {
      return 'family members';
    }
    if (lowerPrompt == 'jobs' || lowerPrompt == 'job' || lowerPrompt == 'work') {
      return 'common jobs and occupations';
    }
    if (lowerPrompt == 'sports' || lowerPrompt == 'sport') {
      return 'sports and games children play';
    }
    if (lowerPrompt == 'music') {
      return 'musical instruments';
    }
    if (lowerPrompt == 'nature') {
      return 'things found in nature';
    }
    if (lowerPrompt == 'kitchen') {
      return 'kitchen items and cooking tools';
    }
    if (lowerPrompt == 'bathroom') {
      return 'bathroom items';
    }
    if (lowerPrompt == 'bedroom') {
      return 'bedroom furniture and items';
    }
    if (lowerPrompt == 'playground') {
      return 'playground equipment and activities';
    }
    if (lowerPrompt == 'garden') {
      return 'garden plants and tools';
    }
    if (lowerPrompt == 'ocean' || lowerPrompt == 'sea') {
      return 'ocean animals and sea creatures';
    }
    if (lowerPrompt == 'space') {
      return 'space objects and planets';
    }
    if (lowerPrompt == 'forest') {
      return 'forest animals and trees';
    }
    if (lowerPrompt == 'holidays' || lowerPrompt == 'holiday') {
      return 'holiday celebrations and traditions';
    }
    if (lowerPrompt == 'seasons' || lowerPrompt == 'season') {
      return 'four seasons and seasonal activities';
    }
    
    // Return original if no enhancement needed
    return prompt;
  }
  
  /// Get topic-specific guidance for better word generation
  /// Prioritizes phonics/pronunciation patterns for children with reading difficulties
  static String _getTopicSpecificGuidance(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    
    // PRIORITY 1: Phonics and pronunciation patterns
    if (lowerPrompt.contains('short') && lowerPrompt.contains('sound')) {
      return '''
CRITICAL: Generate words with the specified SHORT VOWEL SOUND for phonics instruction.
Focus on simple, decodable words that children with reading difficulties can practice.
Examples should be clear pronunciation patterns with the target sound.
Avoid complex words - keep it simple for struggling readers.
''';
    }
    
    if (lowerPrompt.contains('long') && lowerPrompt.contains('sound')) {
      return '''
CRITICAL: Generate words with the specified LONG VOWEL SOUND for phonics instruction.
Focus on simple, decodable words that children with reading difficulties can practice.
Examples should be clear pronunciation patterns with the target sound.
Include various spelling patterns for the same sound (like 'ay', 'ai', 'a_e' for long a).
''';
    }
    
    if (lowerPrompt.contains('cvc') || (lowerPrompt.contains('letter') && !lowerPrompt.contains('long') && !lowerPrompt.contains('short'))) {
      return '''
CRITICAL: Generate simple consonant-vowel-consonant words for beginning readers.
Focus on decodable words that follow basic phonics patterns.
Examples: cat, dog, sun, big, hop, run
Keep words simple and easy to sound out for children with reading difficulties.
''';
    }
    
    if (lowerPrompt.contains('ending') || lowerPrompt.contains('family') || lowerPrompt.contains('-')) {
      return '''
CRITICAL: Generate words from the same WORD FAMILY for phonics practice.
All words must have the same ending pattern for pronunciation practice.
Examples: cat, bat, hat, sat (all -at family)
This helps children with reading difficulties learn consistent sound patterns.
''';
    }
    
    if (lowerPrompt.contains('blend') || lowerPrompt.contains('digraph')) {
      return '''
CRITICAL: Generate words with the specified CONSONANT BLEND or DIGRAPH.
Focus on words that clearly demonstrate the target sound combination.
Keep words at appropriate level for children with reading difficulties.
Examples should be decodable and follow phonics rules.
''';
    }
    
    // Animal-related prompts (secondary priority)
    if (lowerPrompt.contains('animal')) {
      return '''
CRITICAL: Generate only ACTUAL ANIMAL NAMES, not farm items or related words.
Examples: cow, pig, horse, chicken, duck, sheep, goat, rabbit, cat, dog
DO NOT include: milk, farmer, barn, feed, water, straw, field, etc.
''';
    }
    
    // Farm-related prompts
    if (lowerPrompt.contains('farm')) {
      return '''
CRITICAL: Generate only things you would actually FIND ON A FARM.
Examples: cow, pig, chicken, barn, tractor, corn, wheat, fence, farmer, horse
Focus on specific farm animals, crops, buildings, and equipment.
''';
    }
    
    // Color prompts
    if (lowerPrompt.contains('color')) {
      return '''
CRITICAL: Generate only ACTUAL COLOR NAMES.
Examples: red, blue, green, yellow, orange, purple, pink, brown, black, white
DO NOT include: crayon, paint, rainbow, art, etc.
''';
    }
    
    // Food prompts
    if (lowerPrompt.contains('food')) {
      return '''
CRITICAL: Generate only ACTUAL FOOD ITEMS you can eat.
Examples: apple, bread, milk, cheese, chicken, rice, pasta, banana
DO NOT include: plate, fork, kitchen, cook, etc.
''';
    }
    
    // Transportation prompts
    if (lowerPrompt.contains('transport') || lowerPrompt.contains('vehicle')) {
      return '''
CRITICAL: Generate only ACTUAL VEHICLES and transportation methods.
Examples: car, truck, bus, train, plane, bike, boat, ship
DO NOT include: road, driver, gas, wheel, etc.
''';
    }
    
    // Body parts
    if (lowerPrompt.contains('body')) {
      return '''
CRITICAL: Generate only ACTUAL BODY PART NAMES.
Examples: head, hand, foot, arm, leg, eye, nose, mouth
DO NOT include: doctor, health, medicine, etc.
''';
    }
    
    // Numbers
    if (lowerPrompt.contains('number')) {
      return '''
CRITICAL: Generate only NUMBER WORDS (spelled out).
Examples: one, two, three, four, five, six, seven, eight, nine, ten
DO NOT include: count, math, add, plus, etc.
''';
    }
    
    // Weather
    if (lowerPrompt.contains('weather')) {
      return '''
CRITICAL: Generate only ACTUAL WEATHER CONDITIONS and phenomena.
Examples: sunny, rain, snow, wind, cloud, storm, hot, cold
DO NOT include: forecast, umbrella, coat, etc.
''';
    }
    
    // Default guidance for other topics
    return '''
CRITICAL: Generate only words that are DIRECT EXAMPLES of "$prompt".
Focus on specific items, names, or examples that belong to this category.
Avoid related items, tools, or associated concepts - only the actual thing itself.
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
    
    // Check for ending pattern (e.g., "ending in -it", "ending with at", "end in it")
    final endingPattern = RegExp(r'(?:ending|end|ends|that end) (?:in|with) ["\x27]?(-?\w+)["\x27]?').firstMatch(lowerPrompt);
    if (endingPattern != null) {
      final ending = endingPattern.group(1)?.replaceAll('-', '');
      patternInstructions += '- ALL words MUST end with the letters "$ending"\n';
      patternInstructions += '- CRITICAL: Every single word must have "$ending" as its final letters\n';
      patternInstructions += '- DO NOT include words ending with any other letters\n';
      patternInstructions += '- Examples of correct words ending in "$ending": ${_getExampleWords(ending ?? '')}\n';
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
  
  /// Parse AI response into a 6x6 grid with strict validation
  static List<List<String>> _parseWordGrid(String aiResponse, {String? requiredEnding, int? requiredLength, String originalPrompt = ''}) {
    // Clean and split the response more aggressively
    var words = aiResponse
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'[^\w\s,-]'), '') // Remove unwanted characters
        .split(',')
        .map((word) => word.trim().toLowerCase())
        .where((word) => word.isNotEmpty && word.length > 1) // Must be at least 2 characters
        .toList();
    
    print('🤖 Raw AI response words: $words');
    
    // CRITICAL: Remove duplicates immediately and aggressively
    final uniqueWords = <String>[];
    final seenWords = <String>{};
    for (final word in words) {
      if (!seenWords.contains(word)) {
        seenWords.add(word);
        uniqueWords.add(word);
      }
    }
    words = uniqueWords;
    print('🤖 After removing duplicates: ${words.length} unique words');
    
    // Apply strict pattern filtering FIRST
    if (requiredEnding != null && requiredEnding.isNotEmpty) {
      print('🤖 STRICT FILTERING: Only words ending with "$requiredEnding"');
      final originalCount = words.length;
      words = words.where((word) {
        final endsCorrectly = word.endsWith(requiredEnding.toLowerCase());
        if (!endsCorrectly) {
          print('🚫 REJECTED "$word" - does not end with "$requiredEnding"');
        }
        return endsCorrectly;
      }).toList();
      
      print('🤖 Strict ending filter: ${originalCount} → ${words.length} words');
      
      // If AI didn't provide enough valid words, use curated fallbacks
      if (words.length < 36) {
        final fallbackWords = _getFallbackWordsForEnding(requiredEnding.toLowerCase());
        print('🤖 Adding fallback words ending in "$requiredEnding": $fallbackWords');
        
        // Add fallback words that aren't already in the list
        for (final word in fallbackWords) {
          if (!words.contains(word) && word.endsWith(requiredEnding.toLowerCase())) {
            words.add(word);
            if (words.length >= 36) break;
          }
        }
      }
    }
    
    // Apply length filtering if specified
    if (requiredLength != null) {
      print('🤖 STRICT FILTERING: Only $requiredLength-letter words');
      final originalCount = words.length;
      words = words.where((word) {
        final correctLength = word.length == requiredLength;
        if (!correctLength) {
          print('🚫 REJECTED "$word" - has ${word.length} letters, need $requiredLength');
        }
        return correctLength;
      }).toList();
      
      print('🤖 Strict length filter: ${originalCount} → ${words.length} words');
      
      // If we don't have enough words of the required length, add fallbacks
      if (words.length < 36) {
        final fallbackWords = _getFallbackWordsForLength(requiredLength, lowerPrompt: originalPrompt.toLowerCase());
        print('🤖 Adding $requiredLength-letter fallback words: $fallbackWords');
        
        for (final word in fallbackWords) {
          if (!words.contains(word) && word.length == requiredLength) {
            words.add(word);
            if (words.length >= 36) break;
          }
        }
      }
    }
    
    // CRITICAL: Remove overly complex words that are inappropriate for children
    final bannedComplexWords = {
      'preeminent', 'eleemosynary', 'exceedingly', 'magnificent', 'extraordinary',
      'apprehensive', 'articulate', 'austere', 'abrasive', 'acquiesce', 'amenable',
      'aggregate', 'ambivalence', 'accentuate', 'sophisticated', 'complicated',
      'elaborate', 'substantial', 'significant', 'appropriate', 'unfortunate',
      'tremendous', 'incredible', 'remarkable', 'wonderful', 'beautiful',
      'important', 'different', 'interesting', 'excellent', 'fantastic'
    };
    
    // Filter out complex words and keep only simple ones
    words = words.where((word) {
      // Must be 2-6 letters for elementary children
      if (word.length < 2 || word.length > 6) {
        print('🚫 REJECTED "$word" - wrong length (${word.length} letters)');
        return false;
      }
      
      // Must not be in banned complex words list
      if (bannedComplexWords.contains(word.toLowerCase())) {
        print('🚫 REJECTED "$word" - too complex for children');
        return false;
      }
      
      return true;
    }).toList();
    
    // CRITICAL: Ensure no duplicates in final list
    final finalUniqueWords = <String>[];
    final finalSeenWords = <String>{};
    for (final word in words) {
      if (!finalSeenWords.contains(word)) {
        finalSeenWords.add(word);
        finalUniqueWords.add(word);
      }
    }
    words = finalUniqueWords;
    
    print('🤖 Final validated word list (${words.length}): ${words.take(10).toList()}...');
    
    // Ensure we have exactly 36 words - pad with safe, simple defaults if needed
    final simpleDefaults = ['cat', 'dog', 'run', 'sun', 'big', 'red', 'top', 'hop', 'sit', 'hit'];
    int defaultIndex = 0;
    while (words.length < 36) {
      final defaultWord = simpleDefaults[defaultIndex % simpleDefaults.length];
      if (!words.contains(defaultWord)) {
        words.add(defaultWord);
      } else {
        words.add('${defaultWord}${words.length}'); // Add number to make unique
      }
      defaultIndex++;
    }
    if (words.length > 36) {
      words = words.take(36).toList();
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
  
  /// Get example words for a given ending pattern
  static String _getExampleWords(String ending) {
    switch (ending.toLowerCase()) {
      case 'at':
        return 'cat, bat, mat, sat, hat, rat';
      case 'it':
        return 'sit, hit, bit, fit, kit, lit';
      case 'et':
        return 'pet, get, let, met, net, set';
      case 'ot':
        return 'hot, pot, dot, got, lot, not';
      case 'ut':
        return 'cut, but, hut, nut, put, gut';
      case 'an':
        return 'can, man, ran, pan, fan, tan';
      case 'en':
        return 'pen, ten, men, hen, den, when';
      case 'in':
        return 'pin, win, tin, bin, fin, skin';
      case 'un':
        return 'run, sun, fun, bun, spun, stun';
      case 'ing':
        return 'ring, sing, king, wing, bring, spring';
      default:
        return '';
    }
  }
  
  /// Get fallback words for a specific length requirement
  static List<String> _getFallbackWordsForLength(int length, {String lowerPrompt = ''}) {
    // Check if looking for short 'a' sound words
    if (lowerPrompt.contains('short a') || lowerPrompt.contains('short vowel a')) {
      switch (length) {
        case 4:
          return ['hand', 'land', 'sand', 'band', 'back', 'pack', 'rack', 'sack', 'tack', 'glad', 'crab', 'grab', 'trap', 'snap', 'clap', 'flat', 'that', 'chat', 'brat', 'slam', 'swam', 'gram', 'tram', 'plan', 'scan', 'span', 'than', 'clan', 'bran', 'drag', 'flag', 'stag', 'snag', 'camp', 'damp', 'lamp', 'ramp', 'past', 'fast', 'last', 'cast', 'vast', 'mask', 'task', 'bath', 'path', 'math'];
        case 3:
          return ['cat', 'bat', 'hat', 'mat', 'rat', 'sat', 'fat', 'pat', 'vat', 'can', 'man', 'pan', 'ran', 'fan', 'tan', 'van', 'bad', 'dad', 'had', 'lad', 'mad', 'sad', 'bag', 'gag', 'lag', 'rag', 'tag', 'wag', 'nap', 'cap', 'gap', 'lap', 'map', 'rap', 'tap', 'zap'];
        case 5:
          return ['grand', 'stand', 'brand', 'black', 'crack', 'track', 'stack', 'glass', 'grass', 'class', 'flash', 'crash', 'trash', 'smash', 'plant', 'chant', 'grant', 'ranch', 'batch', 'catch', 'match', 'patch', 'watch', 'happy', 'snack'];
        default:
          return [];
      }
    }
    
    // Generic fallbacks by length
    switch (length) {
      case 3:
        return ['the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'her', 'was', 'one', 'our', 'out', 'day', 'got', 'him', 'his', 'how', 'its', 'let', 'new', 'now', 'old', 'see', 'two', 'way', 'who', 'boy', 'did', 'get', 'has', 'put', 'say', 'she', 'too', 'use'];
      case 4:
        return ['have', 'that', 'with', 'this', 'will', 'your', 'from', 'they', 'know', 'want', 'been', 'good', 'much', 'some', 'time', 'very', 'when', 'come', 'here', 'just', 'like', 'long', 'make', 'many', 'over', 'such', 'take', 'than', 'them', 'well', 'only', 'year', 'work', 'back', 'call', 'came', 'feel', 'find', 'give', 'hand', 'high', 'keep', 'last', 'left', 'life', 'live', 'look', 'made', 'most', 'move', 'must', 'name', 'need', 'next', 'open', 'part', 'play', 'said', 'seem', 'show', 'side', 'tell', 'turn', 'used', 'want', 'ways', 'week', 'went', 'were', 'what', 'word', 'work'];
      case 5:
        return ['about', 'after', 'again', 'along', 'being', 'below', 'could', 'every', 'first', 'found', 'great', 'house', 'large', 'little', 'never', 'other', 'place', 'right', 'small', 'sound', 'still', 'there', 'these', 'thing', 'think', 'three', 'under', 'until', 'water', 'where', 'which', 'while', 'world', 'would', 'write', 'years'];
      default:
        return [];
    }
  }
  
  /// Get educational fallback words for a specific ending pattern
  /// These are carefully curated for children with reading difficulties
  /// CRITICAL: All words MUST actually end with the specified pattern and be age-appropriate
  static List<String> _getFallbackWordsForEnding(String ending) {
    switch (ending.toLowerCase()) {
      case 'at':
        return ['cat', 'bat', 'mat', 'sat', 'hat', 'rat', 'pat', 'fat', 'vat', 'chat', 'flat', 'that'];
      case 'it':
        return ['sit', 'hit', 'bit', 'fit', 'kit', 'lit', 'pit', 'wit', 'quit', 'spit', 'knit', 'grit', 'slit', 'flit', 'split'];
      case 'et':
        return ['pet', 'get', 'let', 'met', 'net', 'set', 'bet', 'jet', 'wet', 'yet', 'vet'];
      case 'ot':
        return ['hot', 'pot', 'dot', 'got', 'lot', 'not', 'cot', 'jot', 'rot', 'tot', 'shot', 'spot', 'plot', 'knot', 'slot'];
      case 'ut':
        return ['cut', 'but', 'hut', 'nut', 'put', 'gut', 'jut', 'rut', 'shut'];
      case 'an':
        return ['can', 'man', 'ran', 'pan', 'fan', 'tan', 'ban', 'van', 'plan', 'than', 'scan', 'span'];
      case 'en':
        return ['pen', 'ten', 'men', 'hen', 'den', 'when', 'then'];
      case 'in':
        return ['pin', 'win', 'tin', 'bin', 'fin', 'skin', 'spin', 'thin', 'chin', 'twin', 'grin', 'shin'];
      case 'un':
        return ['run', 'sun', 'fun', 'bun', 'spun', 'stun', 'nun'];
      case 'ay':
        return ['day', 'way', 'say', 'may', 'bay', 'hay', 'lay', 'pay', 'play', 'stay', 'pray', 'gray'];
      case 'all':
        return ['ball', 'call', 'fall', 'hall', 'mall', 'tall', 'wall', 'small'];
      case 'ell':
        return ['bell', 'fell', 'sell', 'tell', 'well', 'yell', 'spell', 'shell'];
      case 'ill':
        return ['bill', 'fill', 'hill', 'mill', 'pill', 'will', 'spill', 'still', 'gill', 'till'];
      case 'ack':
        return ['back', 'pack', 'sack', 'jack', 'lack', 'rack', 'tack', 'black', 'crack', 'track'];
      case 'ick':
        return ['kick', 'lick', 'pick', 'sick', 'tick', 'wick', 'thick', 'quick', 'stick', 'brick'];
      case 'ock':
        return ['dock', 'lock', 'rock', 'sock', 'block', 'clock', 'knock', 'shock', 'stock'];
      case 'uck':
        return ['duck', 'luck', 'buck', 'muck', 'suck', 'tuck', 'stuck', 'truck'];
      default:
        return [];
    }
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