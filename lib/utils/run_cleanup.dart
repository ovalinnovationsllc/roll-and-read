import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'firebase_cleanup.dart';

/// Simple script to run Firebase cleanup
/// This can be run from the main app or as a standalone operation
Future<void> runFirebaseCleanup() async {
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
    
    // In a real app, you'd want user confirmation here
    // For now, we'll just run the check
    
  } catch (e) {
    print('❌ Error initializing Firebase: $e');
    rethrow;
  }
}

/// Actually perform the migration (call this only after confirming)
Future<void> performMigration() async {
  print('\n🔄 === PERFORMING MIGRATION ===');
  await FirebaseCleanup.migrateObsoleteCollections();
  print('✅ Migration completed!');
}

/// Just check what collections exist (safe operation)
Future<void> checkOnly() async {
  try {
    // Initialize Firebase if not already done
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    await FirebaseCleanup.checkObsoleteCollections();
  } catch (e) {
    print('❌ Error checking collections: $e');
  }
}