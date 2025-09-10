import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/custom_word_list_service.dart';
import 'lib/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('🔍 Updating all word lists to be shared...');

  try {
    // Get all word lists (not just shared ones)
    final firestore = FirebaseFirestore.instance;
    final querySnapshot = await firestore
        .collection('custom_word_lists')
        .get();
    
    print('📊 Found ${querySnapshot.docs.length} total word lists');
    
    int updatedCount = 0;
    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final isShared = data['isShared'] ?? false;
      
      if (!isShared) {
        // Update this document to be shared
        await doc.reference.update({'isShared': true});
        updatedCount++;
        print('✅ Updated "${data['title']}" to be shared');
      } else {
        print('⚪ "${data['title']}" already shared');
      }
    }
    
    print('🎉 Updated $updatedCount word lists to be shared');
    print('📊 Total word lists now available: ${querySnapshot.docs.length}');
    
  } catch (e) {
    print('❌ Error updating word lists: $e');
  }
}