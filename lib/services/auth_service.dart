import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign up with Email and Password
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // Update display name in Firebase Auth profile
        await user.updateDisplayName(displayName);
        await user.reload();

        // Create user document in Firestore
        await _db.collection('users').doc(user.uid).set({
          'email': email,
          'displayName': displayName,
          'photoURL': user.photoURL,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      return credential;
    } catch (e) {
      throw Exception('Sign up failed: ${e.toString().replaceAll(RegExp(r'\[.*\]\s*'), '')}');
    }
  }

  // Sign in with Email and Password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Login failed: ${e.toString().replaceAll(RegExp(r'\[.*\]\s*'), '')}');
    }
  }

  // Sign in with Google (using Popup for Web ease)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      
      final UserCredential credential = await _auth.signInWithPopup(googleProvider);
      final user = credential.user;
      
      if (user != null) {
        final userDoc = await _db.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          await _db.collection('users').doc(user.uid).set({
            'email': user.email,
            'displayName': user.displayName ?? 'Google User',
            'photoURL': user.photoURL,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      }
      return credential;
    } catch (e) {
      throw Exception('Google Sign-In failed: ${e.toString().replaceAll(RegExp(r'\[.*\]\s*'), '')}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString().replaceAll(RegExp(r'\[.*\]\s*'), '')}');
    }
  }
}
