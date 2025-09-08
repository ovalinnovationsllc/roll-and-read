import 'lib/services/content_filter_service.dart';

void main() {
  print('Testing word safety:');
  print('owl is safe: ${ContentFilterService.isWordSafe('owl')}');
  print('hen is safe: ${ContentFilterService.isWordSafe('hen')}');
  print('');
  
  // Test the second row of animals
  final row2 = ['lion', 'tiger', 'wolf', 'fox', 'deer', 'owl'];
  print('Testing row 2 animals: $row2');
  final filtered = ContentFilterService.filterWords(row2);
  print('Filtered result: $filtered');
  print('');
  
  // Check each word individually
  for (final word in row2) {
    final safe = ContentFilterService.isWordSafe(word);
    print('$word: ${safe ? "SAFE" : "FILTERED"}');
  }
}