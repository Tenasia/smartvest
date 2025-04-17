import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential; // Return the UserCredential
    } on FirebaseAuthException catch (e) {
      // Handle errors appropriately (see improved error handling below)
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      throw e; // Re-throw the exception to be caught by the UI
    } catch (e) {
      print("General Error: $e");
      throw Exception("An unexpected error occurred: $e");
    }
    return null;
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      throw e;
    } catch (e) {
      print("General Error: $e");
      throw Exception("Failed to sign up: $e");
    }
    return null;
  }

  //  Forgot Password
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      throw e;
    } catch (e) {
      print("Error sending password reset email: $e");
      throw Exception("Failed to send password reset email: $e");
    }
  }

  // Get the current user
  User? get currentUser {
    return _auth.currentUser;
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
