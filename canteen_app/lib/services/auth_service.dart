import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Authentication Service for Google Sign-In and Firebase Auth
/// Supports both Web and Mobile platforms
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Initialize GoogleSignIn WITHOUT clientId for web
  // Web uses meta tag in index.html instead
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Sign in with Google
  /// Returns authenticated User or null if cancelled/failed
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // User cancelled the sign-in
      if (googleUser == null) {
        return null;
      }

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Create or update user document in Firestore
        await _createOrUpdateUser(user);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      // Handle Firebase-specific errors
      throw _handleFirebaseError(e);
    } catch (e) {
      // Handle generic errors
      throw 'Failed to sign in with Google: ${e.toString()}';
    }
  }

  /// Sign in with Email and Password (existing method)
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  /// Sign out from Firebase and Google
  Future<void> signOut() async {
    try {
      // Sign out from Google if user signed in with Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      
      // Sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      throw 'Failed to sign out: ${e.toString()}';
    }
  }

  /// Create or update user document in Firestore
  /// Only creates new document on first login
  Future<void> _createOrUpdateUser(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    // Only create if document doesn't exist (first login)
    if (!userDoc.exists) {
      await userRef.set({
        'name': user.displayName ?? 'User',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'role': 'student', // Default role for Google Sign-In users
        'createdAt': FieldValue.serverTimestamp(),
        'provider': 'google',
      });
    } else {
      // Update photo URL and name if changed
      await userRef.update({
        'name': user.displayName ?? userDoc.data()?['name'] ?? 'User',
        'photoUrl': user.photoURL ?? userDoc.data()?['photoUrl'] ?? '',
        'lastLogin': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Handle Firebase Auth errors with readable messages
  String _handleFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in method.';
      case 'invalid-credential':
        return 'The credential is invalid or has expired.';
      case 'operation-not-allowed':
        return 'Google Sign-In is not enabled. Please contact support.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'popup-blocked':
        return 'Sign-in popup was blocked. Please allow popups for this site.';
      case 'popup-closed-by-user':
        return 'Sign-in was cancelled.';
      default:
        return e.message ?? 'An error occurred during authentication.';
    }
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
