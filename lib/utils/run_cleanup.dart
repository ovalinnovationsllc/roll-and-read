import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'firebase_cleanup.dart';

/// Simple script to run Firebase cleanup
/// This can be run from the main app or as a standalone operation
Future<void> runFirebaseCleanup() async {
  
  try {
    // Initialize Firebase if not already done
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    
    
    // First, do a dry run to see what exists
    await FirebaseCleanup.checkObsoleteCollections();
    
    
    // In a real app, you'd want user confirmation here
    // For now, we'll just run the check
    
  } catch (e) {
    rethrow;
  }
}

/// Actually perform the migration (call this only after confirming)
Future<void> performMigration() async {
  await FirebaseCleanup.migrateObsoleteCollections();
}

/// Just check what collections exist (safe operation)
Future<void> checkOnly() async {
  try {
    // Initialize Firebase if not already done
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    
    await FirebaseCleanup.checkObsoleteCollections();
  } catch (e) {
  }
}