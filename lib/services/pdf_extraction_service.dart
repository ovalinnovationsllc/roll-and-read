import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import '../data/ufli_word_lists.dart';

/// Service for extracting word lists from UFLI PDF files
class PDFExtractionService {
  
  /// Pick and process a PDF file
  static Future<PDFExtractionResult> pickAndExtractPDF() async {
    try {
      print('PDFExtractionService: Starting file picker...');
      print('Platform: ${kIsWeb ? "Web" : "Mobile/Desktop"}');
      
      // Let user pick a PDF file
      FilePickerResult? result;
      
      try {
        print('Calling FilePicker.platform.pickFiles...');
        // Try simpler approach first
        result = await FilePicker.platform.pickFiles(
          type: FileType.any, // Changed from custom to any
          allowMultiple: false,
          withData: true, // Important for web support
        );
        print('FilePicker result: ${result != null ? "File selected" : "No file selected"}');
        
        // Check if it's a PDF
        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          if (!file.name.toLowerCase().endsWith('.pdf')) {
            return PDFExtractionResult(
              success: false,
              message: 'Please select a PDF file',
              extractedWords: {},
            );
          }
        }
      } catch (e) {
        print('Error picking file: $e');
        print('Stack trace: ${StackTrace.current}');
        return PDFExtractionResult(
          success: false,
          message: 'Error selecting file: $e',
          extractedWords: {},
        );
      }
      
      if (result == null || result.files.isEmpty) {
        return PDFExtractionResult(
          success: false,
          message: 'No file selected',
          extractedWords: {},
        );
      }
      
      final file = result.files.first;
      
      // Get file bytes
      Uint8List? bytes;
      
      // For web, bytes should be available directly
      if (file.bytes != null) {
        bytes = file.bytes!;
      } 
      // For mobile platforms, read from path
      else if (!kIsWeb && file.path != null) {
        try {
          final fileData = File(file.path!);
          bytes = await fileData.readAsBytes();
        } catch (e) {
          print('Error reading file from path: $e');
          return PDFExtractionResult(
            success: false,
            message: 'Could not read file: $e',
            extractedWords: {},
          );
        }
      } else {
        return PDFExtractionResult(
          success: false,
          message: 'Could not read file - no data available',
          extractedWords: {},
        );
      }
      
      // Extract text from PDF
      final extractedText = await _extractTextFromPDF(bytes);
      
      // Detect UFLI list type from filename or content
      final detectedType = _detectUFLIListType(file.name, extractedText);
      
      // Extract words from text
      final words = _extractWordsFromText(extractedText, file.name);
      
      if (words.isEmpty) {
        return PDFExtractionResult(
          success: false,
          message: 'No words found in PDF',
          extractedWords: {},
        );
      }
      
      // Create word list map
      final wordLists = <String, List<String>>{};
      if (detectedType != null) {
        wordLists[detectedType] = words;
      } else {
        // If we can't detect type, prompt user to select
        wordLists['unknown'] = words;
      }
      
      return PDFExtractionResult(
        success: true,
        message: 'Extracted ${words.length} words from ${file.name}',
        extractedWords: wordLists,
        detectedType: detectedType,
        fileName: file.name,
      );
      
    } catch (e) {
      return PDFExtractionResult(
        success: false,
        message: 'Error processing PDF: $e',
        extractedWords: {},
      );
    }
  }
  
  /// Extract text from PDF bytes
  static Future<String> _extractTextFromPDF(Uint8List bytes) async {
    try {
      if (bytes.isEmpty) {
        print('Error: PDF bytes are empty');
        return '';
      }
      
      // Load the PDF document
      PdfDocument? document;
      try {
        document = PdfDocument(inputBytes: bytes);
      } catch (e) {
        print('Error loading PDF document: $e');
        return '';
      }
      
      // Create text extractor for the document
      String extractedText = '';
      try {
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        extractedText = extractor.extractText();
      } catch (e) {
        print('Error extracting text from PDF: $e');
      }
      
      // Dispose the document
      try {
        document.dispose();
      } catch (e) {
        print('Error disposing PDF document: $e');
      }
      
      return extractedText;
    } catch (e) {
      print('Unexpected error in PDF extraction: $e');
      return '';
    }
  }
  
  /// Detect UFLI list type from filename and content
  static String? _detectUFLIListType(String fileName, String content) {
    final lowerFileName = fileName.toLowerCase();
    final lowerContent = content.toLowerCase();
    
    // Check filename patterns
    if (lowerFileName.contains('kindergarten') || lowerFileName.contains('k.pdf')) {
      if (lowerContent.contains('letter')) {
        return 'ufli_k_letters';
      }
      return 'ufli_k_cvc';
    }
    
    if (lowerFileName.contains('first') || lowerFileName.contains('1st')) {
      if (lowerContent.contains('blend')) {
        return 'ufli_1_consonant_blends';
      }
      if (lowerContent.contains('vowel')) {
        return 'ufli_1_short_vowels';
      }
      return 'ufli_1_short_vowels';
    }
    
    if (lowerFileName.contains('second') || lowerFileName.contains('2nd')) {
      if (lowerContent.contains('cvce') || lowerContent.contains('magic')) {
        return 'ufli_2_cvce';
      }
      if (lowerContent.contains('digraph')) {
        return 'ufli_2_digraphs';
      }
      return 'ufli_2_cvce';
    }
    
    // Check content patterns
    if (lowerContent.contains('cvce') || lowerContent.contains('magic e')) {
      return 'ufli_2_cvce';
    }
    
    if (lowerContent.contains('digraph')) {
      return 'ufli_2_digraphs';
    }
    
    if (lowerContent.contains('blend')) {
      return 'ufli_1_consonant_blends';
    }
    
    if (lowerContent.contains('r-controlled') || lowerContent.contains('r controlled')) {
      return 'ufli_advanced_r_controlled';
    }
    
    if (lowerContent.contains('short vowel')) {
      return 'ufli_1_short_vowels';
    }
    
    return null;
  }
  
  /// Extract words from text
  static List<String> _extractWordsFromText(String text, [String? fileName]) {
    final words = <String>[];
    
    // Get title words to filter out
    final titleWords = _getTitleWordsToFilter(fileName);
    
    // Split text into lines
    final lines = text.split('\n');
    
    for (final line in lines) {
      // Skip empty lines
      if (line.trim().isEmpty) continue;
      
      // Skip lines that look like headers or instructions
      if (_isHeaderOrInstruction(line)) continue;
      
      // Extract words from the line
      final lineWords = _extractWordsFromLine(line);
      
      // Filter out title words
      for (final word in lineWords) {
        if (!titleWords.contains(word.toLowerCase())) {
          words.add(word);
        }
      }
    }
    
    // Remove duplicates while preserving order
    final uniqueWords = <String>[];
    final seen = <String>{};
    for (final word in words) {
      if (seen.add(word.toLowerCase())) {
        uniqueWords.add(word);
      }
    }
    
    return uniqueWords;
  }
  
  /// Get words from lesson title to filter out of extracted words
  static Set<String> _getTitleWordsToFilter(String? fileName) {
    if (fileName == null) return <String>{};
    
    // Extract lesson title from filename (e.g., "19_RollRead_UFLIFoundations.pdf")
    final titleWords = <String>{};
    
    // Add common UFLI filename components to filter
    titleWords.addAll(['roll', 'read', 'rollread', 'ufli', 'foundations', 'ufl']);
    
    // Extract lesson number and associated words
    final lessonMatch = RegExp(r'(\d+)').firstMatch(fileName);
    if (lessonMatch != null) {
      final lessonNum = lessonMatch.group(1)!;
      titleWords.add(lessonNum);
      titleWords.add('lesson');
    }
    
    // Add other filename components
    final cleanName = fileName.toLowerCase()
        .replaceAll('.pdf', '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    
    final words = cleanName.split(' ');
    for (final word in words) {
      final cleaned = word.trim();
      if (cleaned.isNotEmpty && cleaned.length > 1) {
        titleWords.add(cleaned);
      }
    }
    
    return titleWords;
  }

  /// Check if a line is likely a header or instruction
  static bool _isHeaderOrInstruction(String line) {
    final lower = line.toLowerCase().trim();
    
    // Skip common headers and instructions
    final skipPatterns = [
      'roll and read',
      'directions',
      'instructions',
      'lesson',
      'grade',
      'level',
      'copyright',
      'university',
      'ufli foundations',
      'name:',
      'date:',
      'score:',
      'page',
      'practice',
      'exercise',
      'activity',
      'homework',
      'worksheet',
      'student name',
      'teacher name',
      'circle the',
      'write the',
      'read the',
      'say the',
      'spell the',
      'trace the',
      'match the',
      'connect the',
      'draw a',
      'color the',
      'cut and',
      'paste the',
      'complete the',
      'finish the',
      'review the',
    ];
    
    for (final pattern in skipPatterns) {
      if (lower.contains(pattern)) return true;
    }
    
    // Skip lines with numbers at the beginning (likely page numbers or item numbers)
    if (RegExp(r'^\d+\.?\s').hasMatch(lower)) return true;
    
    // Skip lines that are too long (likely sentences)
    if (line.split(' ').length > 6) return true;
    
    return false;
  }
  
  /// Extract words from a single line
  static List<String> _extractWordsFromLine(String line) {
    final words = <String>[];
    
    // Remove special characters but keep spaces and hyphens
    final cleaned = line.replaceAll(RegExp(r'[^\w\s-]'), ' ');
    
    // Split by whitespace
    final tokens = cleaned.split(RegExp(r'\s+'));
    
    for (final token in tokens) {
      final trimmed = token.trim();
      
      // Skip empty tokens
      if (trimmed.isEmpty) continue;
      
      // Skip single letters (unless it's 'a' or 'I')
      if (trimmed.length == 1 && trimmed.toLowerCase() != 'a' && trimmed.toLowerCase() != 'i') {
        // But if we're looking for letters, keep them
        if (_isLetter(trimmed)) {
          words.add(trimmed.toLowerCase());
        }
        continue;
      }
      
      // Skip numbers
      if (RegExp(r'^\d+$').hasMatch(trimmed)) continue;
      
      // Skip words that are too long (likely not target words)
      if (trimmed.length > 12) continue;
      
      // Add valid word
      words.add(trimmed.toLowerCase());
    }
    
    return words;
  }
  
  /// Check if a string is a single letter
  static bool _isLetter(String str) {
    return RegExp(r'^[a-zA-Z]$').hasMatch(str);
  }
  
  /// Smart word detection for Roll and Read grids
  static List<String> detectRollAndReadWords(String text) {
    final words = <String>[];
    
    // Look for patterns that indicate Roll and Read grids
    // These often have 6x6 grids of words
    
    // Split into lines
    final lines = text.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Skip empty lines
      if (line.isEmpty) continue;
      
      // Look for lines with multiple short words (grid rows)
      final tokens = line.split(RegExp(r'\s+'));
      
      // If we have 4-6 tokens and they're all short words, it's likely a grid row
      if (tokens.length >= 4 && tokens.length <= 6) {
        bool allShortWords = true;
        for (final token in tokens) {
          if (token.length > 8 || token.length < 2) {
            allShortWords = false;
            break;
          }
        }
        
        if (allShortWords) {
          for (final token in tokens) {
            if (_isValidWord(token)) {
              words.add(token.toLowerCase());
            }
          }
        }
      }
    }
    
    return words;
  }
  
  /// Check if a string is a valid word for Roll and Read
  static bool _isValidWord(String word) {
    // Must be 2-8 characters
    if (word.length < 2 || word.length > 8) return false;
    
    // Must contain only letters
    if (!RegExp(r'^[a-zA-Z]+$').hasMatch(word)) return false;
    
    // Should not be all caps (likely an acronym or header)
    if (word == word.toUpperCase() && word.length > 2) return false;
    
    return true;
  }
}

/// Result of PDF extraction
class PDFExtractionResult {
  final bool success;
  final String message;
  final Map<String, List<String>> extractedWords;
  final String? detectedType;
  final String? fileName;
  
  const PDFExtractionResult({
    required this.success,
    required this.message,
    required this.extractedWords,
    this.detectedType,
    this.fileName,
  });
}