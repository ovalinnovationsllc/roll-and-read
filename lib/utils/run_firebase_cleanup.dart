import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'firebase_cleanup.dart';

/// Standalone script to clean up Firebase collections
/// Run this to remove duplicate collections and standardize naming
Future<void> main() async {
<<<<<<< HEAD
  
  try {
    // Initialize Firebase if not already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    
    // First, check what we have
    await FirebaseCleanup.checkObsoleteCollections();
    
    // Run the complete cleanup
    await FirebaseCleanup.cleanupAllDuplicateCollections();
    
    // Check final state
    await FirebaseCleanup.checkObsoleteCollections();
    
    
  } catch (e) {
=======
  print('🚀 Starting Firebase Cleanup Script...');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');
    
    // First, check what we have
    print('\n📊 === CURRENT STATE ===');
    await FirebaseCleanup.checkObsoleteCollections();
    
    // Run the complete cleanup
    print('\n🧹 === STARTING CLEANUP ===');
    await FirebaseCleanup.cleanupAllDuplicateCollections();
    
    // Check final state
    print('\n📊 === FINAL STATE ===');
    await FirebaseCleanup.checkObsoleteCollections();
    
    print('\n🎉 Cleanup script completed successfully!');
    print('\n📋 Final Collections Should Be:');
    print('   ✅ games (unified multiplayer games)');
    print('   ✅ gameStates (game state tracking)');
    print('   ✅ students (student profiles)');
    print('   ✅ users (teacher/admin profiles)');
    print('   ✅ wordLists (AI-generated word lists)');
    print('\n❌ Deleted Collections:');
    print('   ❌ game_states (consolidated into gameStates)');
    print('   ❌ word_lists (consolidated into wordLists)');
    print('   ❌ student_games (replaced by unified games)');
    print('   ❌ student_player_profiles (replaced by students)');
    print('   ❌ kid_games (obsolete naming)');
    print('   ❌ kid_player_profiles (obsolete naming)');
    
  } catch (e) {
    print('❌ Error running cleanup: $e');
    print('\nThis might be normal - some collections may not exist.');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
  }
}