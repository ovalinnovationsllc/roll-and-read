import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_player_profile.dart';

class StudentPlayerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'student_player_profiles';

  // Create a new player profile
  static Future<StudentPlayerProfile?> createProfile({
    required String playerName,
    required String avatarColor,
    required String avatarIcon,
    String? teacherId,
    String? simplePin,
  }) async {
    try {
      final profileId = _firestore.collection(_collection).doc().id;
      final now = DateTime.now();
      
      final profile = StudentPlayerProfile(
        profileId: profileId,
        playerName: playerName,
        avatarColor: avatarColor,
        avatarIcon: avatarIcon,
        teacherId: teacherId,
        createdAt: now,
        lastPlayedAt: now,
        simplePin: simplePin ?? _generateSimplePin(),
      );
      
      await _firestore
          .collection(_collection)
          .doc(profileId)
          .set(profile.toMap());
      
      print('Created student player profile for $playerName with PIN: ${profile.simplePin}');
      return profile;
    } catch (e) {
      print('Error creating player profile: $e');
      return null;
    }
  }

  // Find profile by name and PIN
  static Future<StudentPlayerProfile?> findProfileByNameAndPin({
    required String playerName,
    required String pin,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('playerName', isEqualTo: playerName)
          .where('simplePin', isEqualTo: pin)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return StudentPlayerProfile.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error finding player profile: $e');
      return null;
    }
  }

  // Get profile by ID
  static Future<StudentPlayerProfile?> getProfile(String profileId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(profileId)
          .get();
      
      if (doc.exists) {
        return StudentPlayerProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting player profile: $e');
      return null;
    }
  }

  // Update profile stats after game
  static Future<bool> updateProfileStats({
    required String profileId,
    int? wordsToAdd,
    bool incrementGamesPlayed = false,
    bool incrementTurnsPlayed = false,
  }) async {
    try {
      final updates = <String, dynamic>{
        'lastPlayedAt': FieldValue.serverTimestamp(),
      };
      
      if (wordsToAdd != null && wordsToAdd > 0) {
        updates['wordsRead'] = FieldValue.increment(wordsToAdd);
      }
      
      if (incrementGamesPlayed) {
        updates['gamesPlayed'] = FieldValue.increment(1);
      }
      
      if (incrementTurnsPlayed) {
        updates['turnsPlayed'] = FieldValue.increment(1);
      }
      
      await _firestore
          .collection(_collection)
          .doc(profileId)
          .update(updates);
      
      print('Updated profile stats for $profileId');
      return true;
    } catch (e) {
      print('Error updating profile stats: $e');
      return false;
    }
  }

  // Get teacher's students
  static Stream<List<StudentPlayerProfile>> getTeacherStudents(String teacherId) {
    return _firestore
        .collection(_collection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('lastPlayedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StudentPlayerProfile.fromMap(doc.data()))
            .toList());
  }

  // Get recently active profiles (for quick rejoin)
  static Future<List<StudentPlayerProfile>> getRecentProfiles({int limit = 5}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('lastPlayedAt', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs
          .map((doc) => StudentPlayerProfile.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting recent profiles: $e');
      return [];
    }
  }

  // Generate a simple 4-digit PIN
  static String _generateSimplePin() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return (1000 + (timestamp % 9000)).toString();
  }
}