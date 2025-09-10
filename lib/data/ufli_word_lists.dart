import '../models/word_list_model.dart';
import '../services/content_filter_service.dart';

/// UFLI (University of Florida Literacy Institute) Roll and Read Word Lists
/// Based on the structured phonics and reading progression from UFLI Foundations
class UFLIWordLists {
  
  // UFLI Word List Categories
  static const String CATEGORY_KINDERGARTEN = 'UFLI Kindergarten';
  static const String CATEGORY_FIRST_GRADE = 'UFLI First Grade';
  static const String CATEGORY_SECOND_GRADE = 'UFLI Second Grade';
  static const String CATEGORY_SHORT_VOWELS = 'UFLI Short Vowels';
  static const String CATEGORY_CVCe = 'UFLI CVCe Words';
  static const String CATEGORY_CONSONANT_BLENDS = 'UFLI Consonant Blends';
  static const String CATEGORY_DIGRAPHS = 'UFLI Digraphs';
  static const String CATEGORY_ADVANCED_PHONICS = 'UFLI Advanced Phonics';
  
  /// Placeholder structure for UFLI word lists
  /// To be populated with actual words from the UFLI PDFs
  static final Map<String, UFLIWordListInfo> _wordListCatalog = {
    
    // Kindergarten Lists
    'ufli_k_letters': UFLIWordListInfo(
      id: 'ufli_k_letters',
      title: 'Letter Recognition',
      category: CATEGORY_KINDERGARTEN,
      gradeLevel: GradeLevel.KINDERGARTEN,
      skillFocus: 'Letter identification and sounds',
      lessonNumber: 'K-Letters',
      words: [
        'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 
        'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
      ],
      tags: ['letters', 'phonics', 'kindergarten'],
    ),
    
    'ufli_k_cvc': UFLIWordListInfo(
      id: 'ufli_k_cvc',
      title: 'CVC Words',
      category: CATEGORY_KINDERGARTEN,
      gradeLevel: GradeLevel.KINDERGARTEN,
      skillFocus: 'Consonant-Vowel-Consonant words',
      lessonNumber: 'K-CVC',
      words: [
        'cat', 'bat', 'hat', 'rat', 'mat', 'pat', 'sat', 'fat', 'vat', 'at',
        'can', 'man', 'pan', 'ran', 'tan', 'van', 'fan', 'ban', 'an',
        'cap', 'map', 'tap', 'nap', 'lap', 'gap', 'sap', 'zap', 'rap',
        'cup', 'pup', 'up', 'cut', 'but', 'nut', 'hut', 'rut', 'gut', 'jut',
        'dog', 'log', 'hog', 'jog', 'fog', 'cog', 'bog', 'log',
        'top', 'hop', 'pop', 'mop', 'cop', 'sop', 'lop', 'bop',
        'big', 'dig', 'fig', 'jig', 'pig', 'rig', 'wig', 'zig',
        'bed', 'red', 'led', 'fed', 'wed', 'ted',
        'ten', 'pen', 'hen', 'men', 'den', 'ben', 'yen', 'ken'
      ],
      tags: ['cvc', 'phonics', 'kindergarten'],
    ),
    
    // First Grade Lists
    'ufli_1_short_vowels': UFLIWordListInfo(
      id: 'ufli_1_short_vowels',
      title: 'Short Vowel Sounds',
      category: CATEGORY_FIRST_GRADE,
      gradeLevel: GradeLevel.ELEMENTARY,
      skillFocus: 'Short a, e, i, o, u sounds',
      lessonNumber: '1-Short-Vowels',
      words: [
        'apple', 'ant', 'add', 'ask', 'had', 'bag', 'bad', 'mad', 'sad', 'dad',
        'egg', 'end', 'elf', 'get', 'set', 'bet', 'let', 'met', 'net', 'pet',
        'igloo', 'ink', 'ill', 'sit', 'hit', 'bit', 'fit', 'kit', 'pit', 'wit',
        'ox', 'on', 'odd', 'hot', 'got', 'lot', 'not', 'pot', 'rot', 'dot',
        'up', 'under', 'us', 'bus', 'run', 'fun', 'sun', 'gun', 'bun', 'nun'
      ],
      tags: ['short-vowels', 'phonics', 'first-grade'],
    ),
    
    'ufli_1_consonant_blends': UFLIWordListInfo(
      id: 'ufli_1_consonant_blends',
      title: 'Consonant Blends',
      category: CATEGORY_CONSONANT_BLENDS,
      gradeLevel: GradeLevel.ELEMENTARY,
      skillFocus: 'bl, cl, fl, gl, pl, sl, br, cr, dr, etc.',
      lessonNumber: '1-Blends',
      words: [
        'blue', 'blow', 'black', 'block', 'blend', 'bless', 'blank',
        'clay', 'clap', 'class', 'climb', 'clock', 'close', 'club',
        'flag', 'flip', 'fly', 'flow', 'flat', 'flash', 'float',
        'glad', 'glass', 'glow', 'glue', 'globe', 'glove',
        'play', 'plan', 'plant', 'plus', 'plate', 'place',
        'slow', 'sleep', 'slip', 'slide', 'slam', 'slim',
        'brown', 'bring', 'break', 'bread', 'brush', 'brain',
        'crab', 'crack', 'cry', 'cross', 'crown', 'crash',
        'drop', 'drum', 'draw', 'drive', 'dress', 'dream'
      ],
      tags: ['blends', 'phonics', 'first-grade'],
    ),
    
    // Second Grade Lists
    'ufli_2_cvce': UFLIWordListInfo(
      id: 'ufli_2_cvce',
      title: 'CVCe (Magic E) Words',
      category: CATEGORY_CVCe,
      gradeLevel: GradeLevel.ELEMENTARY,
      skillFocus: 'Long vowel sounds with silent e',
      lessonNumber: '2-CVCe',
      words: [
        'make', 'take', 'cake', 'lake', 'wake', 'sake', 'bake', 'rake', 'name', 'game',
        'hope', 'rope', 'note', 'vote', 'rode', 'code', 'mode', 'pole', 'hole', 'home',
        'cute', 'tube', 'cube', 'mute', 'huge', 'tune', 'dune', 'fuse', 'rule', 'rude',
        'bike', 'like', 'hike', 'pike', 'mike', 'kite', 'bite', 'site', 'time', 'dime',
        'bone', 'tone', 'cone', 'lone', 'gone', 'zone', 'done', 'none', 'some', 'come'
      ],
      tags: ['cvce', 'magic-e', 'long-vowels', 'second-grade'],
    ),
    
    'ufli_2_digraphs': UFLIWordListInfo(
      id: 'ufli_2_digraphs',
      title: 'Consonant Digraphs',
      category: CATEGORY_DIGRAPHS,
      gradeLevel: GradeLevel.ELEMENTARY,
      skillFocus: 'ch, sh, th, wh, ph sounds',
      lessonNumber: '2-Digraphs',
      words: [
        'chair', 'child', 'check', 'church', 'choice', 'change', 'chapter', 'cheese',
        'shop', 'ship', 'shoe', 'short', 'should', 'share', 'shadow', 'shower',
        'think', 'thank', 'three', 'throw', 'through', 'thick', 'thin', 'thumb',
        'where', 'when', 'what', 'which', 'white', 'while', 'wheel', 'whisper',
        'phone', 'photo', 'phrase', 'physical', 'elephant', 'alphabet', 'graph'
      ],
      tags: ['digraphs', 'phonics', 'second-grade'],
    ),
    
    // Advanced Phonics Lists
    'ufli_advanced_r_controlled': UFLIWordListInfo(
      id: 'ufli_advanced_r_controlled',
      title: 'R-Controlled Vowels',
      category: CATEGORY_ADVANCED_PHONICS,
      gradeLevel: GradeLevel.ELEMENTARY,
      skillFocus: 'ar, er, ir, or, ur sounds',
      lessonNumber: 'Advanced-R',
      words: [
        'car', 'far', 'jar', 'star', 'arm', 'art', 'park', 'hard', 'yard', 'card',
        'her', 'fern', 'term', 'verb', 'stern', 'clerk', 'herd', 'nerve', 'serve',
        'bird', 'girl', 'sir', 'stir', 'dirt', 'shirt', 'first', 'third', 'skirt',
        'for', 'or', 'short', 'sport', 'storm', 'torn', 'corn', 'horn', 'born',
        'burn', 'turn', 'hurt', 'surf', 'purse', 'nurse', 'curve', 'turtle'
      ],
      tags: ['r-controlled', 'vowels', 'advanced-phonics'],
    ),
  };
  
  /// Get all available UFLI word list categories
  static List<String> getAllCategories() {
    return [
      CATEGORY_KINDERGARTEN,
      CATEGORY_FIRST_GRADE,
      CATEGORY_SECOND_GRADE,
      CATEGORY_SHORT_VOWELS,
      CATEGORY_CVCe,
      CATEGORY_CONSONANT_BLENDS,
      CATEGORY_DIGRAPHS,
      CATEGORY_ADVANCED_PHONICS,
    ];
  }
  
  /// Get word lists by category
  static List<UFLIWordListInfo> getWordListsByCategory(String category) {
    return _wordListCatalog.values
        .where((wordList) => wordList.category == category)
        .toList()
        ..sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));
  }
  
  /// Get word lists by grade level
  static List<UFLIWordListInfo> getWordListsByGrade(String gradeLevel) {
    return _wordListCatalog.values
        .where((wordList) => wordList.gradeLevel == gradeLevel)
        .toList()
        ..sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));
  }
  
  /// Get a specific word list by ID
  static UFLIWordListInfo? getWordListById(String id) {
    return _wordListCatalog[id];
  }
  
  /// Get all word lists
  static List<UFLIWordListInfo> getAllWordLists() {
    return _wordListCatalog.values.toList()
        ..sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));
  }
  
  /// Convert UFLI word list to WordListModel for use in games
  static WordListModel convertToWordListModel(UFLIWordListInfo ufliList) {
    if (ufliList.words.isEmpty) {
      throw Exception('UFLI word list "${ufliList.title}" has no words. Import the word list first.');
    }
    
    // Apply content filtering to ensure safe words
    final safeWords = ContentFilterService.filterWords(ufliList.words);
    
    // Create 6x6 grid from the word list
    final grid = _createGridFromWords(safeWords);
    
    return WordListModel.create(
      prompt: '${ufliList.title} - ${ufliList.skillFocus}',
      difficulty: _mapGradeTodifficulty(ufliList.gradeLevel),
      wordGrid: grid,
      tags: ['ufli', ...ufliList.tags],
      isPublic: true,
      grade: ufliList.gradeLevel,
      subject: 'phonics',
    );
  }
  
  /// Create a 6x6 grid from a list of words
  static List<List<String>> _createGridFromWords(List<String> words) {
    const totalCells = 36; // 6x6 grid
    
    // Shuffle and select words
    final shuffledWords = List<String>.from(words)..shuffle();
    final selectedWords = <String>[];
    
    // Fill grid with words, repeating if necessary
    for (int i = 0; i < totalCells; i++) {
      if (i < shuffledWords.length) {
        selectedWords.add(shuffledWords[i]);
      } else {
        // Repeat words if we don't have enough
        selectedWords.add(shuffledWords[i % shuffledWords.length]);
      }
    }
    
    // Create 6x6 grid
    final List<List<String>> grid = [];
    for (int i = 0; i < 6; i++) {
      final row = <String>[];
      for (int j = 0; j < 6; j++) {
        final index = i * 6 + j;
        row.add(selectedWords[index]);
      }
      grid.add(row);
    }
    
    return grid;
  }
  
  /// Map UFLI grade level to difficulty string
  static String _mapGradeTodifficulty(String gradeLevel) {
    switch (gradeLevel) {
      case GradeLevel.PRE_K:
        return 'preschool';
      case GradeLevel.KINDERGARTEN:
        return 'kindergarten';
      case GradeLevel.ELEMENTARY:
        return 'elementary';
      case GradeLevel.MIDDLE_SCHOOL:
        return 'intermediate';
      case GradeLevel.HIGH_SCHOOL:
        return 'advanced';
      default:
        return 'elementary';
    }
  }
  
  /// Import word list from raw word data
  static void importWordList(String listId, List<String> words) {
    if (_wordListCatalog.containsKey(listId)) {
      _wordListCatalog[listId] = _wordListCatalog[listId]!.copyWith(words: words);
    } else {
      throw Exception('Unknown UFLI word list ID: $listId');
    }
  }
  
  /// Bulk import multiple word lists
  static void importMultipleWordLists(Map<String, List<String>> wordLists) {
    for (final entry in wordLists.entries) {
      importWordList(entry.key, entry.value);
    }
  }
  
  /// Check if a word list has been imported (has words)
  static bool isWordListImported(String listId) {
    final wordList = _wordListCatalog[listId];
    return wordList != null && wordList.words.isNotEmpty;
  }
  
  /// Get import status for all word lists
  static Map<String, bool> getImportStatus() {
    final status = <String, bool>{};
    for (final entry in _wordListCatalog.entries) {
      status[entry.key] = entry.value.words.isNotEmpty;
    }
    return status;
  }
}

/// Information about a UFLI word list
class UFLIWordListInfo {
  final String id;
  final String title;
  final String category;
  final String gradeLevel;
  final String skillFocus;
  final String lessonNumber;
  final List<String> words;
  final List<String> tags;
  final String? sourceUrl;
  final DateTime? lastUpdated;
  
  const UFLIWordListInfo({
    required this.id,
    required this.title,
    required this.category,
    required this.gradeLevel,
    required this.skillFocus,
    required this.lessonNumber,
    required this.words,
    required this.tags,
    this.sourceUrl,
    this.lastUpdated,
  });
  
  UFLIWordListInfo copyWith({
    String? id,
    String? title,
    String? category,
    String? gradeLevel,
    String? skillFocus,
    String? lessonNumber,
    List<String>? words,
    List<String>? tags,
    String? sourceUrl,
    DateTime? lastUpdated,
  }) {
    return UFLIWordListInfo(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      skillFocus: skillFocus ?? this.skillFocus,
      lessonNumber: lessonNumber ?? this.lessonNumber,
      words: words ?? this.words,
      tags: tags ?? this.tags,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
  
  @override
  String toString() {
    return 'UFLIWordListInfo(id: $id, title: $title, words: ${words.length})';
  }
}