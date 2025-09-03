import '../services/content_filter_service.dart';

/// Manual testing utility for content filter
class TestContentFilter {
  
  /// Test various prompts and print results
  static void testPrompts() {
    final testCases = [
      // Should be BLOCKED
      'damn this is hard',
      'what the hell', 
      'shit words',
      'stupid kids',
      'ugly animals',
      'kill the monster',
      'gun violence',
      'beer and wine',
      'poop words',
      
      // Should be ALLOWED
      'farm animals',
      'CVC words ending in at',
      'sight words for kindergarten', 
      'colors and shapes',
      'rhyming words',
      'phonics patterns',
      'simple animals',
      'action words',
      'basic colors',
    ];
    
    print('=== CONTENT FILTER TEST RESULTS ===');
    
    for (final prompt in testCases) {
      final isBlocked = ContentFilterService.hasInappropriateContent(prompt);
      final status = isBlocked ? '❌ BLOCKED' : '✅ ALLOWED';
      print('$status: "$prompt"');
    }
    
    print('\n=== WORD FILTERING TEST ===');
    
    final mixedWords = [
      'cat', 'dog', 'damn', 'bird', 'shit', 'tree', 'hell', 'book',
      'stupid', 'happy', 'kill', 'run', 'ugly', 'sun', 'fun'
    ];
    
    final safeWords = ContentFilterService.filterWords(mixedWords);
    
    print('Original: ${mixedWords.join(', ')}');
    print('Filtered: ${safeWords.join(', ')}');
    print('Blocked: ${mixedWords.where((w) => !safeWords.contains(w)).join(', ')}');
  }
  
  /// Test AI generation with filtering
  static void testAIPrompts() {
    final prompts = [
      'damn CVC words',  // Should return safe default
      'farm animals',    // Should process normally  
      'shit ending words', // Should return safe default
      'sight words',     // Should process normally
    ];
    
    print('\n=== AI PROMPT FILTERING TEST ===');
    
    for (final prompt in prompts) {
      final isBlocked = ContentFilterService.hasInappropriateContent(prompt);
      if (isBlocked) {
        print('❌ BLOCKED: "$prompt" → Will return safe default grid');
      } else {
        print('✅ ALLOWED: "$prompt" → Will process with AI');
      }
    }
  }
}