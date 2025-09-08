import 'lib/services/ai_word_service.dart';
import 'lib/services/demo_ai_service.dart';
import 'lib/config/app_config.dart';

void main() async {
  print('Testing pattern generation...\n');
  
  // Test patterns that should work
  final patterns = [
    'words with short a sound',
    'words with short o sound', 
    'words ending in -at',
    'words ending in -ing',
    'animals',
    '3 letter CVC words',
  ];
  
  for (final pattern in patterns) {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Pattern: "$pattern"');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try {
      // First try Demo mode
      if (AppConfig.useDemoMode) {
        final demoGrid = await DemoAIService.generateWordGrid(
          prompt: pattern,
          difficulty: 'elementary',
        );
        print('DEMO RESULT:');
        for (var row in demoGrid) {
          print('  ${row.join(', ')}');
        }
      }
      
      // Then try full AI service
      final grid = await AIWordService.generateWordGrid(
        prompt: pattern,
        difficulty: 'elementary',
        gameId: 'TEST',
        gameName: 'Test Game',
      );
      
      print('\nAI SERVICE RESULT:');
      for (var row in grid) {
        print('  ${row.join(', ')}');
      }
      
      // Validate the pattern
      final allWords = grid.expand((r) => r).toList();
      if (pattern.contains('short a')) {
        final invalidWords = allWords.where((w) => !['a', 'ă'].any((v) => w.contains(v))).toList();
        if (invalidWords.isNotEmpty) {
          print('\n❌ INVALID WORDS (no short a sound): $invalidWords');
        }
      } else if (pattern.contains('-at')) {
        final invalidWords = allWords.where((w) => !w.endsWith('at')).toList();
        if (invalidWords.isNotEmpty) {
          print('\n❌ INVALID WORDS (not ending in -at): $invalidWords');
        }
      } else if (pattern.contains('-ing')) {
        final invalidWords = allWords.where((w) => !w.endsWith('ing')).toList();
        if (invalidWords.isNotEmpty) {
          print('\n❌ INVALID WORDS (not ending in -ing): $invalidWords');
        }
      }
      
    } catch (e) {
      print('ERROR: $e');
    }
    
    print('\n');
  }
}