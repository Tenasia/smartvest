import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:flutter/material.dart'; // Import for BuildContext

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password, BuildContext context) async {
    try {
      // Attempt to sign in
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = credential.user;

      if (user != null) {
        // Check user profile completion status in Firestore
        DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(user.uid).get();

        // Check if the document exists before accessing data
        if (userDoc.exists) {
          // Safely cast data, handle potential nulls
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>? ?? {}; // Use empty map as fallback
          bool profileCompleted = userData['profileCompleted'] ?? false;

          // If profile is not marked as completed, redirect to welcome flow
          if (!profileCompleted) {
            print("Email/Pass Sign In: Profile not complete, navigating to /welcome.");
            // Use pushReplacementNamed
            // to prevent going back to login screen
            Navigator.pushReplacementNamed(context, '/welcome');
            // Return null because navigation is handled, preventing further action in the caller
            return null;
          }
          print("Email/Pass Sign In: Profile complete, returning credential.");
        } else {
          // Handle case where user exists in Auth but not Firestore
          print("Warning: User ${user.uid} exists in Auth but not in Firestore. Navigating to /welcome.");
          // Decide recovery flow: navigate to welcome or show error
          Navigator.pushReplacementNamed(context, '/welcome'); // Example: redirect to welcome
          return null;
        }
      }
      // If profile is completed or user is null (though sign-in success implies non-null), return credential
      return credential;
    } on FirebaseAuthException catch (e) {
      // Log specific Firebase Auth errors
      print("Firebase Auth Error during Email/Password Sign-In: ${e.code} - ${e.message}");
      // Re-throw the exception to be handled by the UI layer
      throw e;
    } catch (e) {
      // Log general errors
      print("General Error during Email/Password Sign-In: $e");
      // Throw a more generic exception for the UI
      throw Exception("An unexpected error occurred during sign-in: $e");
    }
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailAndPassword(String email, String password,
      {String? firstName,
        String? lastName,
        String? middleName,
        String? gender,
        DateTime? birthday,
        String? activityLevel,
        int? heightCm,
        double? weightKg}) async {
    try {
      // Create user in Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = credential.user;

      if (user != null) {
        // Create user document in Firestore with initial data
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          // Use providerData array for multi-provider support
          'providerData': [credential.credential?.signInMethod ?? 'password'], // Store initial provider
          'createdAt': FieldValue.serverTimestamp(),
          'welcomeNameCompleted': firstName != null && firstName.isNotEmpty && lastName != null && lastName.isNotEmpty,
          'welcomeGenderCompleted': gender != null && gender.isNotEmpty && birthday != null,
          'activityLevelCompleted': activityLevel != null && activityLevel.isNotEmpty,
          'heightWeightCompleted': heightCm != null && weightKg != null,
          'profileCompleted': false, // Assume profile is not complete initially
          'firstName': firstName ?? '',
          'middleName': middleName ?? '',
          'lastName': lastName ?? '',
          'gender': gender ?? '',
          'birthday': birthday,
          'activityLevel': activityLevel ?? '',
          'heightCm': heightCm,
          'weightKg': weightKg,
          'displayName': user.displayName ?? '', // Add fields expected by Google sign-in merge
          'photoURL': user.photoURL ?? '', // Add fields expected by Google sign-in merge
          'lastSignInTime': FieldValue.serverTimestamp(), // Add fields expected by Google sign-in merge
        });
        print("User document created in Firestore for UID: ${user.uid}");
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error during Email/Password Sign-Up: ${e.code} - ${e.message}");
      throw e; // Re-throw for UI handling
    } catch (e) {
      print("General Error during Email/Password Sign-Up: $e");
      throw Exception("Failed to sign up: $e");
    }
  }

  // Google Sign-In / Sign-Up (Handles both linking and new registration)
  Future<UserCredential?> signInWithGoogle(BuildContext context) async {
    UserCredential? userCredential;
    try {
      // Start Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("Google Sign-In cancelled by user.");
        return null;
      }

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        final userDocRef = _firestore.collection('users').doc(user.uid);
        // Explicitly check if the Firestore document exists *before* deciding merge strategy
        DocumentSnapshot userDocSnapshot = await userDocRef.get();
        final bool userDocExists = userDocSnapshot.exists;
        final bool isNewUserAuth = userCredential.additionalUserInfo?.isNewUser ?? false; // Keep for logging

        print("Google Sign-In: Auth isNewUser: $isNewUserAuth, Firestore doc exists: $userDocExists for UID: ${user.uid}");

        // Base data to always merge/update for Google Sign-In
        Map<String, dynamic> userDataToMerge = {
          'uid': user.uid, // Ensure UID is present
          'email': user.email, // Update email if changed in Google
          'displayName': user.displayName ?? '', // Update display name from Google
          'photoURL': user.photoURL ?? '', // Update photo URL from Google
          'lastSignInTime': FieldValue.serverTimestamp(), // Always update last sign-in time
          // Add 'google' to the list of providers if not already present
          'providerData': FieldValue.arrayUnion([GoogleAuthProvider.PROVIDER_ID]),
        };

        // Add initial fields ONLY if the Firestore document does NOT exist yet
        if (!userDocExists) {
          print("Google Sign-In: Firestore document does NOT exist. Creating with initial defaults.");
          userDataToMerge.addAll({
            'createdAt': FieldValue.serverTimestamp(), // Set creation time only if new doc
            // Initialize all welcome flags and profile status to false
            'welcomeNameCompleted': false,
            'welcomeGenderCompleted': false,
            'activityLevelCompleted': false,
            'heightWeightCompleted': false,
            'profileCompleted': false,
            // Attempt to pre-fill names from Google, otherwise empty strings
            'firstName': user.displayName?.split(' ').first ?? '',
            'lastName': user.displayName!.split(' ').length > 1
                ? user.displayName!.split(' ').sublist(1).join(' ') // Handle multiple last names
                : '',
            // Initialize other profile fields to defaults
            'middleName': '',
            'gender': '',
            'birthday': null,
            'activityLevel': '',
            'heightCm': null,
            'weightKg': null,
            // Note: providerData is already handled in the base map using arrayUnion
          });
        } else {
          print("Google Sign-In: Firestore document exists. Merging core Google data only (displayName, photoURL, email, lastSignInTime, providerData).");
          // For existing documents, userDataToMerge *only* contains the core fields listed above.
          // Crucially, it does NOT contain welcome flags or profileCompleted.
          // SetOptions(merge: true) will preserve the existing values for those fields.
        }

        print("Google Sign-In: Data being merged for UID ${user.uid}: $userDataToMerge");

        // Perform the set operation with merge option
        await userDocRef.set(userDataToMerge, SetOptions(merge: true));

        print("User document ensured/merged in Firestore for UID: ${user.uid}.");

        // --- Post-Sign-In Navigation Logic ---
        // Re-fetch the document AFTER the merge to get the definitive state
        DocumentSnapshot updatedUserDoc = await userDocRef.get(); // Fetch again
        if (updatedUserDoc.exists) {
          Map<String, dynamic> userData = updatedUserDoc.data() as Map<String, dynamic>? ?? {};
          // Read the profileCompleted status AFTER the merge
          bool profileCompleted = userData['profileCompleted'] ?? false;
          print("Google Sign-In: Checking profileCompleted after merge: $profileCompleted");

          // Check for existence of welcome flags after merge (for debugging)
          print("Google Sign-In: Welcome flags after merge: name=${userData.containsKey('welcomeNameCompleted')}, gender=${userData.containsKey('welcomeGenderCompleted')}, activity=${userData.containsKey('activityLevelCompleted')}, heightWeight=${userData.containsKey('heightWeightCompleted')}");


          if (!profileCompleted) {
            print("Google Sign-In: Profile not complete, navigating to /welcome.");
            Navigator.pushReplacementNamed(context, '/welcome');
            return null; // Prevent further navigation in caller
          }
          print("Google Sign-In: Profile complete, returning credential.");
          // If profile is complete, proceed by returning the credential
        } else {
          // This case means the document doesn't exist even after a set/merge, which is unexpected.
          print("Error: Firestore document not found after Google Sign-In/Merge for UID: ${user.uid}. Navigating to /welcome.");
          Navigator.pushReplacementNamed(context, '/welcome'); // Go to welcome flow as profile state is unknown
          return null;
        }
      } else {
        // User object is null after signInWithCredential, should not happen on success
        print("Error: User object is null after successful Google credential sign-in.");
        throw Exception("Failed to retrieve user details after Google Sign-In.");
      }
      // Return the credential if profile is complete
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase errors
      if (e.code == 'account-exists-with-different-credential') {
        print("Firebase Auth Error during Google Sign-In: ${e.code} - Account exists with different credential.");
        throw Exception("An account already exists with this email address using a different sign-in method. Please sign in using your original method.");
      } else {
        print("Firebase Auth Error during Google Sign-In: ${e.code} - ${e.message}");
        throw e; // Re-throw other Firebase errors
      }
    } catch (e) {
      print("General Error during Google Sign-In: $e");
      throw Exception("Failed to sign in with Google: $e");
    }
  }

  // Forgot Password
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print("Password reset email sent successfully to $email");
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error sending password reset: ${e.code} - ${e.message}");
      // Provide user-friendly error messages based on error code
      String errorMessage;
      switch (e.code) {
        case 'invalid-email': // Firebase standard codes often include 'auth/' prefix
        case 'auth/invalid-email':
          errorMessage = 'The email address is invalid.';
          break;
        case 'user-not-found':
        case 'auth/user-not-found':
          errorMessage = 'There is no user record corresponding to this email.';
          break;
        case 'missing-email':
        case 'auth/missing-email':
          errorMessage = 'Please enter an email address.';
          break;
        default:
          errorMessage = 'Failed to send password reset email (${e.code}). Please try again later.';
      }
      throw errorMessage; // Throw the user-friendly message
    } catch (e) {
      print("General Error sending password reset email: $e");
      throw 'An unexpected error occurred while sending the password reset email. Please try again later.';
    }
  }

  // Get the current user
  User? get currentUser {
    return _auth.currentUser;
  }

  // Sign out
  Future<void> signOut() async { // Removed BuildContext context parameter
    User? firebaseUser = _auth.currentUser; // Get user before Firebase sign out

    try {
      // Check if the user was signed in with Google
      bool wasGoogleUser = firebaseUser?.providerData
          .any((info) => info.providerId == GoogleAuthProvider.PROVIDER_ID) ??
          false;

      if (wasGoogleUser) {
        // Attempt to sign out from Google.
        // This is important to allow the user to choose a different Google account next time.
        try {
          print("Attempting GoogleSignIn.signOut()...");
          await _googleSignIn.signOut();
          print("GoogleSignIn.signOut() successful.");
        } catch (e) {
          // Log the error but don't let it stop the Firebase sign-out.
          // This can sometimes happen if the GoogleSignIn session is already stale or misconfigured.
          print("Error during GoogleSignIn.signOut(): $e. Proceeding with Firebase signOut.");
        }
      }

      print("Attempting FirebaseAuth.signOut()...");
      await _auth.signOut();
      print("FirebaseAuth.signOut() successful.");

    } catch (e) {
      print('Error during AuthService.signOut: $e');
      // Rethrow the exception to be caught by the UI layer (ProfileScreen)
      // so it can display an appropriate message to the user.
      rethrow;
    }
  }

  // Helper to check profile completion status (can be called from UI or other services)
  Future<bool> isProfileComplete() async {
    User? user = _auth.currentUser;
    if (user == null) {
      print("isProfileComplete check: No user logged in.");
      return false; // Not logged in
    }

    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};
        bool completed = userData['profileCompleted'] ?? false;
        print("isProfileComplete check for UID ${user.uid}: Found document, profileCompleted = $completed");
        // Also log welcome flags for debugging
        print("isProfileComplete check: welcomeName=${userData['welcomeNameCompleted']}, welcomeGender=${userData['welcomeGenderCompleted']}, activityLevel=${userData['activityLevelCompleted']}, heightWeight=${userData['heightWeightCompleted']}");
        return completed;
      }
      print("isProfileComplete check for UID ${user.uid}: Document does not exist.");
      return false; // Document doesn't exist
    } catch (e) {
      print("Error checking profile completion for UID ${user.uid}: $e");
      return false; // Assume incomplete on error
    }
  }
}
