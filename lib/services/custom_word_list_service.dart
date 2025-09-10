import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/custom_word_list_model.dart';

class CustomWordListService {
  static const String _collection = 'custom_word_lists';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<String> createWordList({
    required String title,
    required List<String> words,
    required String createdBy,
    String? gradeLevel,
    String? description,
    bool isShared = false,
  }) async {
    final wordList = CustomWordListModel.create(
      title: title,
      words: words,
      createdBy: createdBy,
      gradeLevel: gradeLevel,
      description: description,
      isShared: isShared,
    );

    final docRef = await _firestore.collection(_collection).add(wordList.toMap());
    return docRef.id;
  }

  static Future<void> updateWordList(CustomWordListModel wordList) async {
    await _firestore
        .collection(_collection)
        .doc(wordList.id)
        .update(wordList.toMap());
  }

  static Future<void> deleteWordList(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  static Future<CustomWordListModel?> getWordList(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) return null;

    return CustomWordListModel.fromMap(doc.id, doc.data()!);
  }

  static Stream<List<CustomWordListModel>> getWordListsForTeacher(String teacherId) {
    return _firestore
        .collection(_collection)
        .where('createdBy', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CustomWordListModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  static Stream<List<CustomWordListModel>> getSharedWordLists() {
    return _firestore
        .collection(_collection)
        .where('isShared', isEqualTo: true)
        .orderBy('timesUsed', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CustomWordListModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  static Future<List<CustomWordListModel>> getSharedWordListsOnce() async {
    try {
      print('🔍 Querying Firebase for shared word lists...');
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isShared', isEqualTo: true)
          .get();
      
      print('📊 Found ${querySnapshot.docs.length} documents');
      final wordLists = querySnapshot.docs
          .map((doc) {
            try {
              return CustomWordListModel.fromMap(doc.id, doc.data());
            } catch (e) {
              print('❌ Error parsing document ${doc.id}: $e');
              return null;
            }
          })
          .where((list) => list != null)
          .cast<CustomWordListModel>()
          .toList();
      
      // Sort by lesson number (extract from title) for better organization
      wordLists.sort((a, b) {
        // Extract lesson numbers with optional letter suffix like "Lesson 35a - name"
        final aMatch = RegExp(r'Lesson (\d+)([a-z]?)').firstMatch(a.title);
        final bMatch = RegExp(r'Lesson (\d+)([a-z]?)').firstMatch(b.title);
        
        if (aMatch != null && bMatch != null) {
          final aNum = int.parse(aMatch.group(1)!);
          final bNum = int.parse(bMatch.group(1)!);
          final aLetter = aMatch.group(2) ?? '';
          final bLetter = bMatch.group(2) ?? '';
          
          // First sort by lesson number
          if (aNum != bNum) {
            return aNum.compareTo(bNum);
          }
          
          // If same lesson number, sort by letter suffix (a, b, c)
          return aLetter.compareTo(bLetter);
        }
        
        // Fallback to alphabetical sorting for non-lesson titles
        return a.title.compareTo(b.title);
      });
      
      print('✅ Successfully parsed ${wordLists.length} word lists');
      return wordLists;
    } catch (e) {
      print('❌ Error in getSharedWordListsOnce: $e');
      rethrow;
    }
  }

  static Future<void> incrementUsageCount(String id) async {
    await _firestore.collection(_collection).doc(id).update({
      'timesUsed': FieldValue.increment(1),
      'lastUsed': Timestamp.now(),
    });
  }

  static Future<List<CustomWordListModel>> searchWordLists({
    required String teacherId,
    String? query,
    String? gradeLevel,
  }) async {
    Query queryRef = _firestore
        .collection(_collection)
        .where('createdBy', isEqualTo: teacherId);

    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      queryRef = queryRef.where('gradeLevel', isEqualTo: gradeLevel);
    }

    final snapshot = await queryRef.get();
    var wordLists = snapshot.docs
        .map((doc) => CustomWordListModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();

    if (query != null && query.isNotEmpty) {
      wordLists = wordLists.where((wordList) =>
          wordList.title.toLowerCase().contains(query.toLowerCase()) ||
          (wordList.description?.toLowerCase().contains(query.toLowerCase()) ?? false)
      ).toList();
    }

    return wordLists;
  }
}