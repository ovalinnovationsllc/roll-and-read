import 'package:flutter_test/flutter_test.dart';
import '../lib/services/content_filter_service.dart';

void main() {
  group('ContentFilterService Tests', () {
    test('should block inappropriate prompts', () {
      // Test profanity
      expect(ContentFilterService.hasInappropriateContent('damn this is hard'), true);
      expect(ContentFilterService.hasInappropriateContent('what the hell'), true);
      expect(ContentFilterService.hasInappropriateContent('this is shit'), true);
      
      // Test violence
      expect(ContentFilterService.hasInappropriateContent('words about killing'), true);
      expect(ContentFilterService.hasInappropriateContent('gun violence words'), true);
      
      // Test substances  
      expect(ContentFilterService.hasInappropriateContent('beer and wine words'), true);
      expect(ContentFilterService.hasInappropriateContent('drug related words'), true);
      
      // Test bathroom/body
      expect(ContentFilterService.hasInappropriateContent('poop and pee words'), true);
      
      // Test insults
      expect(ContentFilterService.hasInappropriateContent('stupid words'), true);
      expect(ContentFilterService.hasInappropriateContent('ugly and fat words'), true);
    });
    
    test('should allow appropriate educational prompts', () {
      expect(ContentFilterService.hasInappropriateContent('farm animals'), false);
      expect(ContentFilterService.hasInappropriateContent('CVC words ending in at'), false);
      expect(ContentFilterService.hasInappropriateContent('sight words for kindergarten'), false);
      expect(ContentFilterService.hasInappropriateContent('colors and shapes'), false);
      expect(ContentFilterService.hasInappropriateContent('rhyming words'), false);
      expect(ContentFilterService.hasInappropriateContent('phonics patterns'), false);
    });
    
    test('should filter inappropriate words from lists', () {
      final testWords = ['cat', 'dog', 'damn', 'bird', 'shit', 'tree', 'hell', 'book'];
      final filtered = ContentFilterService.filterWords(testWords);
      
      expect(filtered.contains('cat'), true);
      expect(filtered.contains('dog'), true); 
      expect(filtered.contains('bird'), true);
      expect(filtered.contains('tree'), true);
      expect(filtered.contains('book'), true);
      
      expect(filtered.contains('damn'), false);
      expect(filtered.contains('shit'), false);
      expect(filtered.contains('hell'), false);
    });
    
    test('should check individual word safety', () {
      // Safe words
      expect(ContentFilterService.isWordSafe('cat'), true);
      expect(ContentFilterService.isWordSafe('dog'), true);
      expect(ContentFilterService.isWordSafe('tree'), true);
      expect(ContentFilterService.isWordSafe('book'), true);
      
      // Unsafe words
      expect(ContentFilterService.isWordSafe('damn'), false);
      expect(ContentFilterService.isWordSafe('hell'), false);
      expect(ContentFilterService.isWordSafe('shit'), false);
      expect(ContentFilterService.isWordSafe('stupid'), false);
    });
    
    test('should provide safe replacements', () {
      final replacements = ContentFilterService.getSafeReplacements(5);
      expect(replacements.length, 5);
      
      // All replacements should be safe
      for (final word in replacements) {
        expect(ContentFilterService.isWordSafe(word), true);
      }
    });
    
    test('should provide safe word grid', () {
      final grid = ContentFilterService.getSafeWordGrid();
      expect(grid.length, 6); // 6 rows
      
      for (int i = 0; i < grid.length; i++) {
        final row = grid[i];
        expect(row.length, 6); // 6 columns
        
        // All words should be safe
        for (int j = 0; j < row.length; j++) {
          final word = row[j];
          if (!ContentFilterService.isWordSafe(word)) {
            print('Unsafe word found at [$i][$j]: "$word"');
          }
          expect(ContentFilterService.isWordSafe(word), true, reason: 'Word "$word" at [$i][$j] should be safe');
        }
      }
    });
  });
}