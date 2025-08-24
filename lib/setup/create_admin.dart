// Script to create initial admin user
// Run this file to set up the first admin user in Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

Future<void> main() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Create admin user
    final adminUser = {
      'id': 'admin1',
      'displayName': 'Mrs. Elson',
      'emailAddress': 'admin@school.com',
      'pin': '1234',
      'isAdmin': true,
      'gamesPlayed': 0,
      'gamesWon': 0,
      'wordsCorrect': 0,
      'createdAt': Timestamp.now(),
    };

    // Add to Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc('admin1')
        .set(adminUser);

    print('✅ Admin user created successfully!');
    print('Email: admin@school.com');
    print('PIN: 1234');
    print('You can now login to the admin dashboard.');
  } catch (e) {
    print('❌ Error creating admin user: $e');
  }
}