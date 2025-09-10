import '../data/ufli_lesson_names.dart';

class UFLILesson {
  final String id;
  final String fileName;
  final String displayName;
  final String description;
  final int lessonNumber;
  final String? subLesson;
  final String category;
  final String skill;

  const UFLILesson({
    required this.id,
    required this.fileName,
    required this.displayName,
    required this.description,
    required this.lessonNumber,
    this.subLesson,
    required this.category,
    required this.skill,
  });
}

class UFLILessonsService {
  
  /// Get all available UFLI lessons from uploaded PDFs
  static List<UFLILesson> getAllLessons() {
    final List<UFLILesson> lessons = [];
    
    // Map all the uploaded PDF files to lesson objects
    final lessonData = [
      // Basic Letter Sounds (13-34)
      UFLILesson(id: '13', fileName: '13_RollRead_UFLIFoundations.pdf', displayName: 'Letter D Words', description: 'Practice letter D sounds and words', lessonNumber: 13, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '14', fileName: '14_RollRead_UFLIFoundations.pdf', displayName: 'Letter C and K Words', description: 'Practice letter C and K sounds', lessonNumber: 14, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '15', fileName: '15_RollRead_UFLIFoundations.pdf', displayName: 'Short U Words', description: 'Short U vowel sound practice', lessonNumber: 15, category: 'Short Vowels', skill: 'Short U'),
      UFLILesson(id: '16', fileName: '16_RollRead_UFLIFoundations.pdf', displayName: 'Letter G Words', description: 'Practice letter G sounds and words', lessonNumber: 16, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '17', fileName: '17_RollRead_UFLIFoundations.pdf', displayName: 'Letter B Words', description: 'Practice letter B sounds and words', lessonNumber: 17, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '18', fileName: '18_RollRead_UFLIFoundations.pdf', displayName: 'Short E Words', description: 'Short E vowel sound practice', lessonNumber: 18, category: 'Short Vowels', skill: 'Short E'),
      UFLILesson(id: '19', fileName: '19_RollRead_UFLIFoundations.pdf', displayName: 'Letter F Words', description: 'Practice letter F sounds and words', lessonNumber: 19, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '20', fileName: '20_RollRead_UFLIFoundations.pdf', displayName: 'Letter S Words', description: 'Practice letter S sounds and words', lessonNumber: 20, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '21', fileName: '21_RollRead_UFLIFoundations.pdf', displayName: 'Letter N Words', description: 'Practice letter N sounds and words', lessonNumber: 21, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '22', fileName: '22_RollRead_UFLIFoundations.pdf', displayName: 'Letter K Words', description: 'Practice letter K sounds and words', lessonNumber: 22, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '23', fileName: '23_RollRead_UFLIFoundations.pdf', displayName: 'Letter H Words', description: 'Practice letter H sounds and words', lessonNumber: 23, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '24', fileName: '24_RollRead_UFLIFoundations.pdf', displayName: 'Letter R Words', description: 'Practice letter R sounds and words', lessonNumber: 24, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '25', fileName: '25-_RollRead_UFLIFoundations.pdf', displayName: 'Letter R Practice', description: 'Additional letter R practice', lessonNumber: 25, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '26', fileName: '26_RollRead_UFLIFoundations.pdf', displayName: 'Letter L Words', description: 'Practice letter L sounds and words', lessonNumber: 26, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '27', fileName: '27_RollRead_UFLIFoundations.pdf', displayName: 'Letter P Words', description: 'Practice letter P sounds and words', lessonNumber: 27, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '28', fileName: '28_RollRead_UFLIFoundations.pdf', displayName: 'Letter W Words', description: 'Practice letter W sounds and words', lessonNumber: 28, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '29', fileName: '29_RollRead_UFLIFoundations.pdf', displayName: 'Letter J Words', description: 'Practice letter J sounds and words', lessonNumber: 29, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '30', fileName: '30_RollRead_UFLIFoundations.pdf', displayName: 'Letter Y Words', description: 'Practice letter Y sounds and words', lessonNumber: 30, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '31', fileName: '31_RollRead_UFLIFoundations.pdf', displayName: 'Letter X Words', description: 'Practice letter X sounds and words', lessonNumber: 31, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '32', fileName: '32_RollRead_UFLIFoundations.pdf', displayName: 'QU Words', description: 'Practice QU letter combination', lessonNumber: 32, category: 'Letter Sounds', skill: 'Letter Combinations'),
      UFLILesson(id: '33', fileName: '33_RollRead_UFLIFoundations.pdf', displayName: 'Letter V Words', description: 'Practice letter V sounds and words', lessonNumber: 33, category: 'Letter Sounds', skill: 'Basic Letters'),
      UFLILesson(id: '34', fileName: '34_RollRead_UFLIFoundations.pdf', displayName: 'Letter Z Words', description: 'Practice letter Z sounds and words', lessonNumber: 34, category: 'Letter Sounds', skill: 'Basic Letters'),
      
      // Short Vowel Reviews (35-41)
      UFLILesson(id: '35a', fileName: '35a_RollRead_UFLI-Foundations.pdf', displayName: 'Short A Practice', description: 'Short A vowel sound review', lessonNumber: 35, subLesson: 'a', category: 'Short Vowels', skill: 'Short A'),
      UFLILesson(id: '35b', fileName: '35b_RollRead_UFLI-Foundations.pdf', displayName: 'Nasal A Words (am, an, ang)', description: 'Short A with nasal sounds', lessonNumber: 35, subLesson: 'b', category: 'Short Vowels', skill: 'Short A'),
      UFLILesson(id: '35c', fileName: '35c_RollRead_UFLI-Foundations.pdf', displayName: 'Short A with Blends', description: 'Short A with consonant blends', lessonNumber: 35, subLesson: 'c', category: 'Short Vowels', skill: 'Short A'),
      UFLILesson(id: '36a', fileName: '36a_RollRead_UFLI-Foundations.pdf', displayName: 'Short I Practice', description: 'Short I vowel sound review', lessonNumber: 36, subLesson: 'a', category: 'Short Vowels', skill: 'Short I'),
      UFLILesson(id: '36b', fileName: '36b_RollRead_UFLI-Foundations.pdf', displayName: 'Short I with Blends', description: 'Short I with consonant blends', lessonNumber: 36, subLesson: 'b', category: 'Short Vowels', skill: 'Short I'),
      UFLILesson(id: '37a', fileName: '37a_RollRead_UFLI-Foundations.pdf', displayName: 'Short O Practice', description: 'Short O vowel sound review', lessonNumber: 37, subLesson: 'a', category: 'Short Vowels', skill: 'Short O'),
      UFLILesson(id: '37b', fileName: '37b_RollRead_UFLI-Foundations.pdf', displayName: 'Short O with Blends', description: 'Short O with consonant blends', lessonNumber: 37, subLesson: 'b', category: 'Short Vowels', skill: 'Short O'),
      UFLILesson(id: '38a', fileName: '38a_RollRead_UFLI-Foundations.pdf', displayName: 'Short A, I, O Review', description: 'Mixed short vowels A, I, O', lessonNumber: 38, subLesson: 'a', category: 'Short Vowels', skill: 'Mixed Short Vowels'),
      UFLILesson(id: '38b', fileName: '38b_RollRead_UFLI-Foundations.pdf', displayName: 'Short A, I, O with Blends', description: 'Mixed short vowels with blends', lessonNumber: 38, subLesson: 'b', category: 'Short Vowels', skill: 'Mixed Short Vowels'),
      UFLILesson(id: '39a', fileName: '39a_RollRead_UFLI-Foundations.pdf', displayName: 'Short U Practice', description: 'Short U vowel sound review', lessonNumber: 39, subLesson: 'a', category: 'Short Vowels', skill: 'Short U'),
      UFLILesson(id: '39b', fileName: '39b_RollRead_UFLI-Foundations.pdf', displayName: 'Short U with Blends', description: 'Short U with consonant blends', lessonNumber: 39, subLesson: 'b', category: 'Short Vowels', skill: 'Short U'),
      UFLILesson(id: '40a', fileName: '40a_RollRead_UFLI-Foundations.pdf', displayName: 'Short E Practice', description: 'Short E vowel sound review', lessonNumber: 40, subLesson: 'a', category: 'Short Vowels', skill: 'Short E'),
      UFLILesson(id: '40b', fileName: '40b_RollRead_UFLI-Foundations.pdf', displayName: 'Short E with Blends', description: 'Short E with consonant blends', lessonNumber: 40, subLesson: 'b', category: 'Short Vowels', skill: 'Short E'),
      UFLILesson(id: '41a', fileName: '41a_RollRead_UFLI-Foundations.pdf', displayName: 'All Short Vowels Review', description: 'Review all short vowel sounds', lessonNumber: 41, subLesson: 'a', category: 'Short Vowels', skill: 'Mixed Short Vowels'),
      UFLILesson(id: '41b', fileName: '41b_RollRead_UFLI-Foundations.pdf', displayName: 'Mixed Short Vowels - Part 1', description: 'Advanced short vowel practice', lessonNumber: 41, subLesson: 'b', category: 'Short Vowels', skill: 'Mixed Short Vowels'),
      UFLILesson(id: '41c', fileName: '41c_RollRead_UFLI-Foundations.pdf', displayName: 'Mixed Short Vowels - Part 2', description: 'Advanced short vowel practice', lessonNumber: 41, subLesson: 'c', category: 'Short Vowels', skill: 'Mixed Short Vowels'),
      
      // Advanced Patterns (42-66)
      UFLILesson(id: '42', fileName: '42_RollRead_UFLI-Foundations.pdf', displayName: 'FF, LL, SS Endings', description: 'Double consonant endings', lessonNumber: 42, category: 'Patterns', skill: 'Double Consonants'),
      UFLILesson(id: '43', fileName: '43_RollRead_UFLI-Foundations.pdf', displayName: 'ALL, OLL, ULL Words', description: 'Words ending in -all, -oll, -ull', lessonNumber: 43, category: 'Patterns', skill: 'Word Endings'),
      UFLILesson(id: '44', fileName: '44_RollRead_UFLI-Foundations.pdf', displayName: 'CK Ending Words', description: 'Words ending in -ck', lessonNumber: 44, category: 'Patterns', skill: 'Word Endings'),
      UFLILesson(id: '45', fileName: '45_RollRead_UFLI-Foundations.pdf', displayName: 'SH Words', description: 'SH digraph practice', lessonNumber: 45, category: 'Digraphs', skill: 'SH'),
      UFLILesson(id: '46', fileName: '46_RollRead_UFLI-Foundations.pdf', displayName: 'TH Words (voiced)', description: 'Voiced TH digraph practice', lessonNumber: 46, category: 'Digraphs', skill: 'TH'),
      UFLILesson(id: '47', fileName: '47_RollRead_UFLI-Foundations.pdf', displayName: 'TH Words (both sounds)', description: 'Both TH sounds practice', lessonNumber: 47, category: 'Digraphs', skill: 'TH'),
      UFLILesson(id: '48', fileName: '48_RollRead_UFLI-Foundations.pdf', displayName: 'CH Words', description: 'CH digraph practice', lessonNumber: 48, category: 'Digraphs', skill: 'CH'),
      UFLILesson(id: '49', fileName: '49_RollRead_UFLI-Foundations.pdf', displayName: 'Digraph Review - Part 1', description: 'Review of digraphs learned', lessonNumber: 49, category: 'Digraphs', skill: 'Review'),
      UFLILesson(id: '50', fileName: '50_RollRead_UFLI-Foundations.pdf', displayName: 'WH and PH Words', description: 'WH and PH digraph practice', lessonNumber: 50, category: 'Digraphs', skill: 'WH/PH'),
      UFLILesson(id: '51', fileName: '51_RollRead_UFLI-Foundations.pdf', displayName: 'NG Ending Words', description: 'Words ending in -ng', lessonNumber: 51, category: 'Digraphs', skill: 'NG'),
      UFLILesson(id: '52', fileName: '52_RollRead_UFLI-Foundations.pdf', displayName: 'NK Ending Words', description: 'Words ending in -nk', lessonNumber: 52, category: 'Patterns', skill: 'Word Endings'),
      UFLILesson(id: '53', fileName: '53_RollRead_UFLI-Foundations.pdf', displayName: 'Digraph Review - Part 2', description: 'Comprehensive digraph review', lessonNumber: 53, category: 'Digraphs', skill: 'Review'),
      UFLILesson(id: '54', fileName: '54_RollRead_UFLI-Foundations.pdf', displayName: 'A-E (Magic E)', description: 'Long A with silent E', lessonNumber: 54, category: 'Long Vowels', skill: 'Magic E'),
      UFLILesson(id: '55', fileName: '55_RollRead_UFLI-Foundations.pdf', displayName: 'I-E (Magic E)', description: 'Long I with silent E', lessonNumber: 55, category: 'Long Vowels', skill: 'Magic E'),
      UFLILesson(id: '56', fileName: '56_RollRead_UFLI-Foundations.pdf', displayName: 'O-E (Magic E)', description: 'Long O with silent E', lessonNumber: 56, category: 'Long Vowels', skill: 'Magic E'),
      UFLILesson(id: '57', fileName: '57_RollRead_UFLI-Foundations.pdf', displayName: 'U-E (Magic E)', description: 'Long U with silent E', lessonNumber: 57, category: 'Long Vowels', skill: 'Magic E'),
      UFLILesson(id: '58', fileName: '58_RollRead_UFLI-Foundations.pdf', displayName: 'Long U Spellings', description: 'Different ways to spell long U', lessonNumber: 58, category: 'Long Vowels', skill: 'Long U'),
      UFLILesson(id: '59', fileName: '59_RollRead_UFLI-Foundations.pdf', displayName: 'E-E (Magic E)', description: 'Long E with silent E', lessonNumber: 59, category: 'Long Vowels', skill: 'Magic E'),
      UFLILesson(id: '60', fileName: '60_RollRead_UFLI-Foundations.pdf', displayName: 'Soft C Words', description: 'C makes /s/ sound', lessonNumber: 60, category: 'Patterns', skill: 'Soft Consonants'),
      UFLILesson(id: '61', fileName: '61_RollRead_UFLI-Foundations.pdf', displayName: 'Soft C and G Review', description: 'Review soft C and G sounds', lessonNumber: 61, category: 'Patterns', skill: 'Soft Consonants'),
      UFLILesson(id: '62', fileName: '62_RollRead_UFLI-Foundations.pdf', displayName: 'Magic E Exceptions', description: 'Exceptions to magic E rule', lessonNumber: 62, category: 'Long Vowels', skill: 'Magic E'),
      UFLILesson(id: '63', fileName: '63_RollRead_UFLI-Foundations.pdf', displayName: 'ES Ending Words', description: 'Words ending in -es', lessonNumber: 63, category: 'Patterns', skill: 'Word Endings'),
      UFLILesson(id: '64', fileName: '64_RollRead_UFLI-Foundations.pdf', displayName: 'ED Ending Words', description: 'Words ending in -ed', lessonNumber: 64, category: 'Patterns', skill: 'Word Endings'),
      UFLILesson(id: '65', fileName: '65_RollRead_UFLI-Foundations.pdf', displayName: 'ING Ending Words', description: 'Words ending in -ing', lessonNumber: 65, category: 'Patterns', skill: 'Word Endings'),
      UFLILesson(id: '66', fileName: '66_RollRead_UFLI-Foundations.pdf', displayName: 'Open vs Closed Syllables', description: 'Syllable types practice', lessonNumber: 66, category: 'Syllables', skill: 'Syllable Types'),
      
      // Multi-Syllable Words (67-76)
      UFLILesson(id: '67a', fileName: '67a_RollRead_UFLI-Foundations.pdf', displayName: 'Compound Words', description: 'Two words joined together', lessonNumber: 67, subLesson: 'a', category: 'Syllables', skill: 'Compound Words'),
      UFLILesson(id: '67b', fileName: '67b_RollRead_UFLI-Foundations.pdf', displayName: 'Two Closed Syllables', description: 'Words with two closed syllables', lessonNumber: 67, subLesson: 'b', category: 'Syllables', skill: 'Syllable Types'),
      UFLILesson(id: '68', fileName: '68_RollRead_UFLI-Foundations.pdf', displayName: 'Open + Closed Syllables', description: 'Mixed syllable types', lessonNumber: 68, category: 'Syllables', skill: 'Syllable Types'),
      UFLILesson(id: '69', fileName: '69_RollRead_UFLI-Foundations.pdf', displayName: 'TCH vs CH Words', description: 'When to use tch vs ch', lessonNumber: 69, category: 'Patterns', skill: 'Spelling Rules'),
      UFLILesson(id: '70', fileName: '70_RollRead_UFLI-Foundations.pdf', displayName: 'DGE Words', description: 'Words ending in -dge', lessonNumber: 70, category: 'Patterns', skill: 'Word Endings'),
      UFLILesson(id: '71', fileName: '71_RollRead_UFLI-Foundations.pdf', displayName: 'TCH and DGE Review', description: 'Review tch and dge patterns', lessonNumber: 71, category: 'Patterns', skill: 'Spelling Rules'),
      UFLILesson(id: '72', fileName: '72_RollRead_UFLI-Foundations.pdf', displayName: 'Long Vowels + Double Consonants', description: 'Long vowel patterns with doubles', lessonNumber: 72, category: 'Patterns', skill: 'Spelling Rules'),
      UFLILesson(id: '73', fileName: '73_RollRead_UFLI-Foundations.pdf', displayName: 'Y as Long I', description: 'Y making long I sound', lessonNumber: 73, category: 'Long Vowels', skill: 'Y Patterns'),
      UFLILesson(id: '74', fileName: '74_RollRead_UFLI-Foundations-1.pdf', displayName: 'Y as Long E', description: 'Y making long E sound', lessonNumber: 74, category: 'Long Vowels', skill: 'Y Patterns'),
      UFLILesson(id: '75', fileName: '75_RollRead_UFLI-Foundations.pdf', displayName: 'Y Pattern Review', description: 'Review of Y sound patterns', lessonNumber: 75, category: 'Long Vowels', skill: 'Y Patterns'),
      UFLILesson(id: '76', fileName: '76_RollRead_UFLI-Foundations.pdf', displayName: 'Ending Patterns Review', description: 'Review of word ending patterns', lessonNumber: 76, category: 'Patterns', skill: 'Review'),
      
      // R-Controlled Vowels (77-83)
      UFLILesson(id: '77', fileName: '77_RollRead_UFLI-Foundations.pdf', displayName: 'AR Words', description: 'AR controlled vowel sounds', lessonNumber: 77, category: 'R-Controlled', skill: 'AR'),
      UFLILesson(id: '78', fileName: '78_RollRead_UFLI-Foundations.pdf', displayName: 'OR Words', description: 'OR controlled vowel sounds', lessonNumber: 78, category: 'R-Controlled', skill: 'OR'),
      UFLILesson(id: '79', fileName: '79_RollRead_UFLI-Foundations.pdf', displayName: 'ORE Words', description: 'ORE controlled vowel sounds', lessonNumber: 79, category: 'R-Controlled', skill: 'OR'),
      UFLILesson(id: '80', fileName: '80_RollRead_UFLI-Foundations.pdf', displayName: 'ER Words', description: 'ER controlled vowel sounds', lessonNumber: 80, category: 'R-Controlled', skill: 'ER'),
      UFLILesson(id: '81', fileName: '81_RollRead_UFLI-Foundations.pdf', displayName: 'IR Words', description: 'IR controlled vowel sounds', lessonNumber: 81, category: 'R-Controlled', skill: 'IR'),
      UFLILesson(id: '82', fileName: '82_RollRead_UFLI-Foundations.pdf', displayName: 'UR Words', description: 'UR controlled vowel sounds', lessonNumber: 82, category: 'R-Controlled', skill: 'UR'),
      UFLILesson(id: '83', fileName: '83_RollRead_UFLI-Foundations.pdf', displayName: 'R-Controlled Review', description: 'Review all R-controlled vowels', lessonNumber: 83, category: 'R-Controlled', skill: 'Review'),
      
      // Long Vowel Teams (84-99)
      UFLILesson(id: '84', fileName: '84_RollRead_UFLI-Foundations.pdf', displayName: 'AI Words (Long A)', description: 'AI making long A sound', lessonNumber: 84, category: 'Vowel Teams', skill: 'AI'),
      UFLILesson(id: '85', fileName: '85_RollRead_UFLI-Foundations.pdf', displayName: 'AY Words (Long A)', description: 'AY making long A sound', lessonNumber: 85, category: 'Vowel Teams', skill: 'AY'),
      UFLILesson(id: '86', fileName: '86_RollRead_UFLI-Foundations.pdf', displayName: 'EE Words (Long E)', description: 'EE making long E sound', lessonNumber: 86, category: 'Vowel Teams', skill: 'EE'),
      UFLILesson(id: '87', fileName: '87_RollRead_UFLI-Foundations.pdf', displayName: 'EA Words (Long E)', description: 'EA making long E sound', lessonNumber: 87, category: 'Vowel Teams', skill: 'EA'),
      UFLILesson(id: '88', fileName: '88_RollRead_UFLI-Foundations.pdf', displayName: 'Long E Spellings', description: 'Multiple ways to spell long E', lessonNumber: 88, category: 'Vowel Teams', skill: 'Long E'),
      UFLILesson(id: '89', fileName: '89_RollRead_UFLI-Foundations.pdf', displayName: 'EY Words (Long E)', description: 'EY making long E sound', lessonNumber: 89, category: 'Vowel Teams', skill: 'EY'),
      UFLILesson(id: '90', fileName: '90_RollRead_UFLI-Foundations.pdf', displayName: 'OA Words (Long O)', description: 'OA making long O sound', lessonNumber: 90, category: 'Vowel Teams', skill: 'OA'),
      UFLILesson(id: '91', fileName: '91_RollRead_UFLI-Foundations.pdf', displayName: 'OW Words (Long O)', description: 'OW making long O sound', lessonNumber: 91, category: 'Vowel Teams', skill: 'OW'),
      UFLILesson(id: '92', fileName: '92_RollRead_UFLI-Foundations.pdf', displayName: 'Long O Spellings', description: 'Multiple ways to spell long O', lessonNumber: 92, category: 'Vowel Teams', skill: 'Long O'),
      UFLILesson(id: '93', fileName: '93_RollRead_UFLI-Foundations.pdf', displayName: 'UE Words (Long U)', description: 'UE making long U sound', lessonNumber: 93, category: 'Vowel Teams', skill: 'UE'),
      UFLILesson(id: '94', fileName: '94_RollRead_UFLI-Foundations.pdf', displayName: 'UI Words (Long U)', description: 'UI making long U sound', lessonNumber: 94, category: 'Vowel Teams', skill: 'UI'),
      UFLILesson(id: '95', fileName: '95_RollRead_UFLI-Foundations.pdf', displayName: 'EW Words (Long U)', description: 'EW making long U sound', lessonNumber: 95, category: 'Vowel Teams', skill: 'EW'),
      UFLILesson(id: '96', fileName: '96_RollRead_UFLI-Foundations.pdf', displayName: 'Long Vowel Teams Review', description: 'Review of long vowel teams', lessonNumber: 96, category: 'Vowel Teams', skill: 'Review'),
      UFLILesson(id: '97', fileName: '97_RollRead_UFLI-Foundations.pdf', displayName: 'IE Words (Long I)', description: 'IE making long I sound', lessonNumber: 97, category: 'Vowel Teams', skill: 'IE'),
      UFLILesson(id: '98', fileName: '98_RollRead_UFLI-Foundations.pdf', displayName: 'IGH Words (Long I)', description: 'IGH making long I sound', lessonNumber: 98, category: 'Vowel Teams', skill: 'IGH'),
      UFLILesson(id: '99', fileName: '99_RollRead_UFLI-Foundations.pdf', displayName: 'Long I Spellings', description: 'Multiple ways to spell long I', lessonNumber: 99, category: 'Vowel Teams', skill: 'Long I'),
      
      // Advanced Patterns (100-128)
      UFLILesson(id: '100', fileName: '100_RollRead_UFLI-Foundations.pdf', displayName: 'OO Words (book)', description: 'Short OO sound patterns', lessonNumber: 100, category: 'Advanced Patterns', skill: 'OO Sounds'),
      UFLILesson(id: '101', fileName: '101_RollRead_UFLI-Foundations.pdf', displayName: 'OO Words (moon)', description: 'Long OO sound patterns', lessonNumber: 101, category: 'Advanced Patterns', skill: 'OO Sounds'),
      UFLILesson(id: '102', fileName: '102_RollRead_UFLI-Foundations.pdf', displayName: 'OO Review', description: 'Review both OO sounds', lessonNumber: 102, category: 'Advanced Patterns', skill: 'OO Sounds'),
      UFLILesson(id: '103', fileName: '103_RollRead_UFLI-Foundations.pdf', displayName: 'OW Words (cow)', description: 'OW diphthong sound', lessonNumber: 103, category: 'Diphthongs', skill: 'OW'),
      UFLILesson(id: '104', fileName: '104_RollRead_UFLI-Foundations.pdf', displayName: 'OU Words (house)', description: 'OU diphthong sound', lessonNumber: 104, category: 'Diphthongs', skill: 'OU'),
      UFLILesson(id: '105', fileName: '105_RollRead_UFLI-Foundations.pdf', displayName: 'OW/OU Review', description: 'Review OW and OU diphthongs', lessonNumber: 105, category: 'Diphthongs', skill: 'Review'),
      UFLILesson(id: '106', fileName: '106_RollRead_UFLI-Foundations.pdf', displayName: 'OI Words (coin)', description: 'OI diphthong sound', lessonNumber: 106, category: 'Diphthongs', skill: 'OI'),
      UFLILesson(id: '107', fileName: '107_RollRead_UFLI-Foundations.pdf', displayName: 'OY Words (boy)', description: 'OY diphthong sound', lessonNumber: 107, category: 'Diphthongs', skill: 'OY'),
      UFLILesson(id: '108', fileName: '108_RollRead_UFLI-Foundations.pdf', displayName: 'OI/OY Review', description: 'Review OI and OY diphthongs', lessonNumber: 108, category: 'Diphthongs', skill: 'Review'),
      UFLILesson(id: '109', fileName: '109_RollRead_UFLI-Foundations.pdf', displayName: 'AU Words (sauce)', description: 'AU vowel team sound', lessonNumber: 109, category: 'Advanced Patterns', skill: 'AU'),
      UFLILesson(id: '110', fileName: '110_RollRead_UFLI-Foundations.pdf', displayName: 'AW Words (saw)', description: 'AW vowel team sound', lessonNumber: 110, category: 'Advanced Patterns', skill: 'AW'),
      UFLILesson(id: '111', fileName: '111_RollRead_UFLI-Foundations.pdf', displayName: 'AU/AW Review', description: 'Review AU and AW patterns', lessonNumber: 111, category: 'Advanced Patterns', skill: 'Review'),
      UFLILesson(id: '112', fileName: '112_RollRead_UFLI-Foundations.pdf', displayName: 'AL Words (walk)', description: 'AL controlled vowel patterns', lessonNumber: 112, category: 'Advanced Patterns', skill: 'AL'),
      UFLILesson(id: '113', fileName: '113_RollRead_UFLI-Foundations.pdf', displayName: 'ALL Words (ball)', description: 'ALL controlled vowel patterns', lessonNumber: 113, category: 'Advanced Patterns', skill: 'ALL'),
      UFLILesson(id: '114', fileName: '114_RollRead_UFLI-Foundations.pdf', displayName: 'WA Words (water)', description: 'WA controlled vowel patterns', lessonNumber: 114, category: 'Advanced Patterns', skill: 'WA'),
      UFLILesson(id: '115', fileName: '115_RollRead_UFLI-Foundations.pdf', displayName: 'WAR Words (warm)', description: 'WAR controlled vowel patterns', lessonNumber: 115, category: 'Advanced Patterns', skill: 'WAR'),
      UFLILesson(id: '116', fileName: '116_RollRead_UFLI-Foundations.pdf', displayName: 'SION Words', description: 'Words ending in -sion', lessonNumber: 116, category: 'Advanced Patterns', skill: 'Suffixes'),
      UFLILesson(id: '117', fileName: '117_RollRead_UFLI-Foundations.pdf', displayName: 'TION Words', description: 'Words ending in -tion', lessonNumber: 117, category: 'Advanced Patterns', skill: 'Suffixes'),
      UFLILesson(id: '118', fileName: '118_RollRead_UFLI-Foundations.pdf', displayName: 'SURE Words', description: 'Words ending in -sure', lessonNumber: 118, category: 'Advanced Patterns', skill: 'Suffixes'),
      UFLILesson(id: '119', fileName: '119_RollRead_UFLI-Foundations.pdf', displayName: 'TURE Words', description: 'Words ending in -ture', lessonNumber: 119, category: 'Advanced Patterns', skill: 'Suffixes'),
      UFLILesson(id: '120', fileName: '120_RollRead_UFLI-Foundations.pdf', displayName: 'Advanced Suffixes Review', description: 'Review advanced suffix patterns', lessonNumber: 120, category: 'Advanced Patterns', skill: 'Review'),
      UFLILesson(id: '121', fileName: '121_RollRead_UFLI-Foundations.pdf', displayName: 'Silent Letters', description: 'Words with silent letters', lessonNumber: 121, category: 'Advanced Patterns', skill: 'Silent Letters'),
      UFLILesson(id: '122', fileName: '122_RollRead_UFLI-Foundations.pdf', displayName: 'Contractions', description: 'Shortened word forms', lessonNumber: 122, category: 'Advanced Patterns', skill: 'Contractions'),
      UFLILesson(id: '123', fileName: '123_RollRead_UFLI-Foundations.pdf', displayName: 'Prefixes', description: 'Word beginnings that change meaning', lessonNumber: 123, category: 'Advanced Patterns', skill: 'Prefixes'),
      UFLILesson(id: '124', fileName: '124_RollRead_UFLI-Foundations.pdf', displayName: 'Compound Word Review', description: 'Advanced compound words', lessonNumber: 124, category: 'Advanced Patterns', skill: 'Compound Words'),
      UFLILesson(id: '125', fileName: '125_RollRead_UFLI-Foundations.pdf', displayName: 'Advanced Pattern Review', description: 'Review of all advanced patterns', lessonNumber: 125, category: 'Advanced Patterns', skill: 'Review'),
      UFLILesson(id: '126', fileName: '126_RollRead_UFLI-Foundations.pdf', displayName: 'Complete UFLI Review', description: 'Comprehensive review of all UFLI skills', lessonNumber: 126, category: 'Review', skill: 'Complete Review'),
      UFLILesson(id: '127', fileName: '127_RollRead_UFLI-Foundations.pdf', displayName: 'Reading Fluency Practice', description: 'Practice reading fluency', lessonNumber: 127, category: 'Fluency', skill: 'Reading Practice'),
      UFLILesson(id: '128', fileName: '128_RollRead_UFLI-Foundations.pdf', displayName: 'Advanced Reading Skills', description: 'Advanced reading and comprehension', lessonNumber: 128, category: 'Fluency', skill: 'Advanced Reading'),
    ];
    
    return lessonData;
  }
  
  /// Get lessons filtered by category
  static List<UFLILesson> getLessonsByCategory(String category) {
    return getAllLessons().where((lesson) => lesson.category == category).toList();
  }
  
  /// Get all available categories
  static List<String> getCategories() {
    final lessons = getAllLessons();
    final categories = lessons.map((lesson) => lesson.category).toSet().toList();
    categories.sort();
    return categories;
  }
  
  /// Search lessons by name or description
  static List<UFLILesson> searchLessons(String query) {
    if (query.isEmpty) return getAllLessons();
    
    final lowercaseQuery = query.toLowerCase();
    return getAllLessons().where((lesson) {
      return lesson.displayName.toLowerCase().contains(lowercaseQuery) ||
             lesson.description.toLowerCase().contains(lowercaseQuery) ||
             lesson.skill.toLowerCase().contains(lowercaseQuery) ||
             lesson.category.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }
  
  /// Get lesson by ID
  static UFLILesson? getLessonById(String id) {
    try {
      return getAllLessons().firstWhere((lesson) => lesson.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Get display names for dropdown (formatted as "Lesson X: Name")
  static List<String> getLessonDropdownOptions() {
    return getAllLessons().map((lesson) => lesson.displayName).toList();
  }
  
  /// Get lesson from dropdown option string
  static UFLILesson? getLessonFromDropdownOption(String option) {
    // Find lesson by displayName since option is now just the displayName
    try {
      return getAllLessons().firstWhere(
        (lesson) => lesson.displayName == option,
      );
    } catch (e) {
      return null;
    }
  }
}