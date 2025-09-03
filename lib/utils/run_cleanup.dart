import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'firebase_cleanup.dart';

/// Simple script to run Firebase cleanup
/// This can be run from the main app or as a standalone operation
Future<void> runFirebaseCleanup() async {
<<<<<<< HEAD
  
  try {
    // Initialize Firebase if not already done
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    
    
    // First, do a dry run to see what exists
    await FirebaseCleanup.checkObsoleteCollections();
    
=======
  print('🚀 Initializing Firebase for cleanup...');
  
  try {
    // Initialize Firebase if not already done
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    print('✅ Firebase initialized successfully');
    
    // First, do a dry run to see what exists
    print('\n🔍 === DRY RUN - Checking Collections ===');
    await FirebaseCleanup.checkObsoleteCollections();
    
    print('\n⚠️  === READY TO MIGRATE ===');
    print('This will:');
    print('1. Copy all documents from kid_games → student_games');  
    print('2. Copy all documents from kid_player_profiles → student_player_profiles');
    print('3. Delete the old kid_ collections');
    print('\nProceed? (This action cannot be undone)');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
    
    // In a real app, you'd want user confirmation here
    // For now, we'll just run the check
    
  } catch (e) {
<<<<<<< HEAD
=======
    print('❌ Error initializing Firebase: $e');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
    rethrow;
  }
}

/// Actually perform the migration (call this only after confirming)
Future<void> performMigration() async {
<<<<<<< HEAD
  await FirebaseCleanup.migrateObsoleteCollections();
=======
  print('\n🔄 === PERFORMING MIGRATION ===');
  await FirebaseCleanup.migrateObsoleteCollections();
  print('✅ Migration completed!');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
}

/// Just check what collections exist (safe operation)
Future<void> checkOnly() async {
  try {
    // Initialize Firebase if not already done
<<<<<<< HEAD
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    
    await FirebaseCleanup.checkObsoleteCollections();
  } catch (e) {
=======
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    await FirebaseCleanup.checkObsoleteCollections();
  } catch (e) {
    print('❌ Error checking collections: $e');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
  }
}