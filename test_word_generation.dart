import 'lib/services/demo_ai_service.dart';
import 'lib/services/content_filter_service.dart';

void main() async {
  print('Testing word generation for "animals"...\n');
  
  // Test Demo AI Service
  final grid = await DemoAIService.generateWordGrid(
    prompt: 'animals',
    difficulty: 'elementary',
  );
  
  print('Generated grid:');
  for (var row in grid) {
    print(row.join(', '));
  }
  
  print('\nTotal words: ${grid.expand((r) => r).length}');
  
  // Test content filter on animal words
  print('\n\nTesting content filter on animal words:');
  final animalWords = ['cat', 'dog', 'fish', 'bird', 'frog', 'bear'];
  final filtered = ContentFilterService.filterWords(animalWords);
  print('Original: $animalWords');
  print('Filtered: $filtered');
  
  // Test getSafeReplacements
  print('\n\nTesting getSafeReplacements(6):');
  final replacements = ContentFilterService.getSafeReplacements(6);
  print('Replacements: $replacements');
}