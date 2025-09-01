import '../models/user_model.dart';
import 'firestore_service.dart';

/// Simple wrapper for FirestoreService user methods
class LocalUserService {
  static Future<UserModel?> getUserByEmail(String email) {
    return FirestoreService.getUserByEmail(email);
  }
}