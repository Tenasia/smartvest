import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
  }

  // Google Sign-Up
  Future<UserCredential?> signUpWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // User cancelled the sign-in
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("Error signing up with Google: $e");
      throw Exception("Failed to sign up with Google: $e");
    }
  }

  //  Forgot Password
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      switch (e.code) {
        case 'auth/invalid-email':
          throw 'The email address is invalid.';
        case 'auth/user-not-found':
          throw 'There is no user record corresponding to this email.';
        default:
          throw 'Failed to send password reset email. Please try again.';
      }
    } catch (e) {
      print("Error sending password reset email: $e");
      throw 'An unexpected error occurred. Please try again.';
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