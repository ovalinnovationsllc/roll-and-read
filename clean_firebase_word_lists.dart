#!/usr/bin/env dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/utils/firebase_cleanup.dart';

/// Standalone script to clean instructional words from Firebase word lists
/// 
/// Run with: dart clean_firebase_word_lists.dart
void main() async {
  try {
    print('🚀 Starting Firebase word list cleanup...');
    
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized');
    
    // Run the cleanup
    await FirebaseCleanup.cleanInstructionalWordsFromWordLists();
    
    print('🎉 Cleanup completed successfully!');
    exit(0);
    
  } catch (e, stackTrace) {
    print('❌ Error during cleanup: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}