import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';

/// Migration script to consolidate students collection into users collection
/// Run this ONCE to migrate all existing student data
class StudentMigration {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static Future<void> runMigration() async {
    print('🚀 Starting Student to User Migration...');
    
    try {
      // Initialize Firebase if needed
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      
      // Step 1: Get all students from students collection
      print('📚 Reading students collection...');
      final studentsSnapshot = await _firestore.collection('students').get();
      print('Found ${studentsSnapshot.docs.length} students to migrate');
      
      if (studentsSnapshot.docs.isEmpty) {
        print('No students to migrate');
        return;
      }
      
      // Step 2: Migrate each student to users collection
      int migrated = 0;
      int skipped = 0;
      int errors = 0;
      
      for (final studentDoc in studentsSnapshot.docs) {
        try {
          final studentData = studentDoc.data();
          final studentId = studentDoc.id;
          
          // Check if user already exists
          final existingUser = await _firestore.collection('users').doc(studentId).get();
          
          if (existingUser.exists) {
            print('⚠️ User $studentId already exists, updating with student data...');
            
            // Update existing user with student fields
            await _firestore.collection('users').doc(studentId).update({
              'teacherId': studentData['teacherId'],
              'gamesPlayed': studentData['gamesPlayed'] ?? 0,
              'gamesWon': studentData['gamesWon'] ?? 0,
              'wordsRead': studentData['wordsRead'] ?? 0,
              'lastPlayedAt': studentData['lastPlayedAt'],
              'isStudent': true, // Mark as migrated student
            });
            skipped++;
          } else {
            // Create new user from student data
            final userData = {
              'id': studentId,
              'displayName': studentData['displayName'] ?? 'Student',
              'emailAddress': '${studentId}@student.local',
              'isAdmin': false,
              'teacherId': studentData['teacherId'],
              'gamesPlayed': studentData['gamesPlayed'] ?? 0,
              'gamesWon': studentData['gamesWon'] ?? 0,
              'wordsRead': studentData['wordsRead'] ?? 0,
              'createdAt': studentData['createdAt'] ?? Timestamp.now(),
              'lastPlayedAt': studentData['lastPlayedAt'],
              'playerColor': studentData['playerColor'],
              'avatarUrl': studentData['avatarUrl'],
              'isActive': studentData['isActive'] ?? true,
              'isStudent': true, // Mark as migrated student
            };
            
            await _firestore.collection('users').doc(studentId).set(userData);
            migrated++;
          }
          
          print('✅ Migrated: ${studentData['displayName']} (ID: $studentId)');
        } catch (e) {
          errors++;
          print('❌ Error migrating student ${studentDoc.id}: $e');
        }
      }
      
      print('\n📊 Migration Summary:');
      print('✅ Successfully migrated: $migrated students');
      print('⚠️ Updated existing: $skipped students');
      print('❌ Errors: $errors');
      
      // Step 3: Verify migration
      print('\n🔍 Verifying migration...');
      final usersWithTeacher = await _firestore
          .collection('users')
          .where('isAdmin', isEqualTo: false)
          .where('teacherId', isNotEqualTo: null)
          .get();
      
      print('Found ${usersWithTeacher.docs.length} students in users collection');
      
      print('\n✅ Migration complete!');
      print('⚠️ IMPORTANT: Do NOT delete students collection yet!');
      print('Test the app thoroughly before removing the old collection.');
      
    } catch (e) {
      print('❌ Migration failed: $e');
    }
  }
  
  /// Verify that all students were migrated correctly
  static Future<void> verifyMigration() async {
    print('🔍 Verifying student migration...');
    
    final studentsSnapshot = await _firestore.collection('students').get();
    final studentIds = studentsSnapshot.docs.map((d) => d.id).toSet();
    
    final usersSnapshot = await _firestore
        .collection('users')
        .where('isStudent', isEqualTo: true)
        .get();
    final userIds = usersSnapshot.docs.map((d) => d.id).toSet();
    
    final missing = studentIds.difference(userIds);
    
    if (missing.isEmpty) {
      print('✅ All students have been migrated!');
    } else {
      print('⚠️ Missing ${missing.length} students in users collection:');
      for (final id in missing) {
        print('  - $id');
      }
    }
  }
  
  /// Rollback migration (emergency use only)
  static Future<void> rollbackMigration() async {
    print('⚠️ Rolling back migration...');
    
    // Delete migrated students from users collection
    final migratedStudents = await _firestore
        .collection('users')
        .where('isStudent', isEqualTo: true)
        .get();
    
    int deleted = 0;
    for (final doc in migratedStudents.docs) {
      await doc.reference.delete();
      deleted++;
    }
    
    print('✅ Rolled back $deleted student records from users collection');
  }
}

// Run the migration
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StudentMigration.runMigration();
  
  // Uncomment to verify
  // await StudentMigration.verifyMigration();
  
  // Uncomment only if you need to rollback
  // await StudentMigration.rollbackMigration();
}