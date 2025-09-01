import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';
import 'lib/utils/firebase_cleanup.dart';

/// Standalone script to check Firebase collections
/// Run with: dart check_collections.dart
void main() async {
  print('🔍 Firebase Collections Checker');
  print('================================\n');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    print('✅ Connected to Firebase\n');
    
    // Check what collections exist
    await FirebaseCleanup.checkObsoleteCollections();
    
    print('\n📋 Summary:');
    print('- This script only READS your Firebase data');
    print('- No data was modified or deleted');
    print('- To perform the actual cleanup, update the script');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}