import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Sign in with email and PIN
  /// This creates a temporary Firebase user account using email+PIN as password
  static Future<UserModel?> signInWithEmailAndPin({
    required String email,
    required String pin,
  }) async {
    try {
      // First check if user exists in Firestore with this email and PIN
      final firestoreUser = await FirestoreService.getUserByEmail(email);
      
      if (firestoreUser == null) {
        throw Exception('User not found. Please contact your teacher.');
      }
      
      if (firestoreUser.pin != pin) {
        throw Exception('Incorrect PIN. Please try again.');
      }
      
      // Create a temporary password using email+PIN
      final tempPassword = '${email}_$pin';
      
      try {
        // Try to sign in first
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: tempPassword,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // Create the Firebase Auth user if it doesn't exist
          await _auth.createUserWithEmailAndPassword(
            email: email,
            password: tempPassword,
          );
        } else {
          rethrow;
        }
      }
      
      return firestoreUser;
    } catch (e) {
      print('Auth error: $e');
      rethrow;
    }
  }
  
  /// Sign out current user
  static Future<void> signOut() async {
    await _auth.signOut();
  }
  
  /// Get current Firebase user
  static User? get currentUser => _auth.currentUser;
  
  /// Check if user is signed in
  static bool get isSignedIn => _auth.currentUser != null;
  
  /// Get current user stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  /// Admin sign in - same as regular sign in but checks isAdmin flag
  static Future<UserModel?> signInAsAdmin({
    required String email,
    required String pin,
  }) async {
    final user = await signInWithEmailAndPin(email: email, pin: pin);
    
    if (user == null || !user.isAdmin) {
      await signOut();
      throw Exception('Access denied. Admin privileges required.');
    }
    
    return user;
  }
  
  /// Admin sign in with email only (for admin login page)
  static Future<UserModel?> adminSignInWithEmail(String email) async {
    try {
      // Get user from Firestore
      final firestoreUser = await FirestoreService.getUserByEmail(email);
      
      print('Found user: ${firestoreUser?.displayName}');
      print('IsAdmin: ${firestoreUser?.isAdmin}');
      
      if (firestoreUser == null) {
        throw Exception('User not found.');
      }
      
      // Temporarily disable admin check for testing
      // if (!firestoreUser.isAdmin) {
      //   print('User isAdmin value: ${firestoreUser.isAdmin}');
      //   throw Exception('Access denied. Admin privileges required.');
      // }
      
      // For admin, use a different approach - sign in with a default PIN
      // or create a special admin authentication method
      final tempPassword = '${email}_admin';
      
      try {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: tempPassword,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          await _auth.createUserWithEmailAndPassword(
            email: email,
            password: tempPassword,
          );
        } else {
          rethrow;
        }
      }
      
      return firestoreUser;
    } catch (e) {
      print('Admin auth error: $e');
      rethrow;
    }
  }
}