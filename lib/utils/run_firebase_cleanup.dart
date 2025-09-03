import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'firebase_cleanup.dart';

/// Standalone script to clean up Firebase collections
/// Run this to remove duplicate collections and standardize naming
Future<void> main() async {
  
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
  }
}
