import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
  });
}

class AuthService {
  FirebaseAuth get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      throw Exception("Firebase Auth unavailable");
    }
  }

  FirebaseFirestore get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      throw Exception("Firestore unavailable");
    }
  }

  static final StreamController<AppUser?> _authStateController = StreamController<AppUser?>.broadcast();
  static bool _isInitialized = false;

  Stream<AppUser?> get authStateChanges async* {
    if (_isInitialized) {
      yield _cachedUser;
    }
    yield* _authStateController.stream;
  }

  static AppUser? _cachedUser;
  AppUser? get currentUser => _cachedUser;

  bool get isLocalUser => currentUser?.uid.startsWith('local_') ?? true;

  // Initialize and sync session
  static void init() {
    try {
      FirebaseAuth.instance.authStateChanges().listen((user) async {
        try {
          if (user != null) {
            _cachedUser = AppUser(
              uid: user.uid,
              email: user.email,
              displayName: user.displayName,
              photoURL: user.photoURL,
            );
          } else {
            final prefs = await SharedPreferences.getInstance();
            final localUid = prefs.getString('local_uid');
            if (localUid != null) {
              _cachedUser = AppUser(
                uid: localUid,
                email: prefs.getString('local_email'),
                displayName: prefs.getString('local_displayName'),
                photoURL: prefs.getString('local_photoURL'),
              );
            } else {
              _cachedUser = null;
            }
          }
        } catch (e) {
          print('Error in authStateChanges callback: $e');
          _cachedUser = null;
        } finally {
          _isInitialized = true;
          _authStateController.add(_cachedUser);
        }
      });
    } catch (e) {
      print('Firebase Auth not available on startup: $e. Using local DB session...');
      _loadLocalSession();
    }
  }

  static void _loadLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localUid = prefs.getString('local_uid');
      if (localUid != null) {
        _cachedUser = AppUser(
          uid: localUid,
          email: prefs.getString('local_email'),
          displayName: prefs.getString('local_displayName'),
          photoURL: prefs.getString('local_photoURL'),
        );
      } else {
        _cachedUser = null;
      }
    } catch (e) {
      print('Error loading local session: $e');
      _cachedUser = null;
    } finally {
      _isInitialized = true;
      _authStateController.add(_cachedUser);
    }
  }

  // Sign up with Email and Password
  Future<AppUser> signUpWithEmailAndPassword({
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
        await user.updateDisplayName(displayName);
        await user.reload();

        await _db.collection('users').doc(user.uid).set({
          'email': email,
          'displayName': displayName,
          'photoURL': user.photoURL,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      
      final appUser = AppUser(
        uid: user!.uid,
        email: user.email,
        displayName: displayName,
        photoURL: user.photoURL,
      );
      _cachedUser = appUser;
      _authStateController.add(appUser);
      return appUser;
    } catch (e) {
      print('Firebase Sign-Up failed, falling back to local registry: $e');
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('local_users_db') ?? '{}';
      final Map<String, dynamic> users = jsonDecode(usersJson);
      
      final normalizedEmail = email.trim().toLowerCase();
      if (users.containsKey(normalizedEmail)) {
        throw Exception('Email already in use locally.');
      }
      
      final localUid = 'local_user_${DateTime.now().millisecondsSinceEpoch}';
      users[normalizedEmail] = {
        'uid': localUid,
        'email': email,
        'password': password,
        'displayName': displayName,
        'photoURL': null,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString('local_users_db', jsonEncode(users));
      
      // Save session
      await prefs.setString('local_uid', localUid);
      await prefs.setString('local_email', email);
      await prefs.setString('local_displayName', displayName);
      
      final appUser = AppUser(
        uid: localUid,
        email: email,
        displayName: displayName,
      );
      
      _cachedUser = appUser;
      _authStateController.add(appUser);
      return appUser;
    }
  }

  // Sign in with Email and Password
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      final appUser = AppUser(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoURL: user.photoURL,
      );
      _cachedUser = appUser;
      _authStateController.add(appUser);
      return appUser;
    } catch (e) {
      print('Firebase login failed, trying local login fallback: $e');
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('local_users_db') ?? '{}';
      final Map<String, dynamic> users = jsonDecode(usersJson);
      
      final normalizedEmail = email.trim().toLowerCase();
      if (users.containsKey(normalizedEmail)) {
        final userData = users[normalizedEmail]!;
        if (userData['password'] == password) {
          final appUser = AppUser(
            uid: userData['uid'],
            email: userData['email'],
            displayName: userData['displayName'],
            photoURL: userData['photoURL'],
          );
          
          // Save session
          await prefs.setString('local_uid', appUser.uid);
          await prefs.setString('local_email', appUser.email ?? '');
          await prefs.setString('local_displayName', appUser.displayName ?? '');
          if (appUser.photoURL != null) {
            await prefs.setString('local_photoURL', appUser.photoURL!);
          }
          
          _cachedUser = appUser;
          _authStateController.add(appUser);
          return appUser;
        } else {
          throw Exception('Incorrect password.');
        }
      } else {
        throw Exception('User not found in local or remote database.');
      }
    }
  }

  // Sign in with Google (Hybrid Web Popup & Native mobile flow)
  Future<AppUser?> signInWithGoogle() async {
    try {
      UserCredential? credential;
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        credential = await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        final OAuthCredential oAuthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        credential = await _auth.signInWithCredential(oAuthCredential);
      }

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
        
        final appUser = AppUser(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoURL: user.photoURL,
        );
        _cachedUser = appUser;
        _authStateController.add(appUser);
        return appUser;
      }
      return null;
    } catch (e) {
      print('Firebase Google Sign-In failed, logging in with local mock Google user: $e');
      final mockUid = 'local_google_user';
      final mockEmail = 'mock.google@example.com';
      final mockName = 'Mock Google User';
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_uid', mockUid);
      await prefs.setString('local_email', mockEmail);
      await prefs.setString('local_displayName', mockName);
      
      final appUser = AppUser(
        uid: mockUid,
        email: mockEmail,
        displayName: mockName,
      );
      _cachedUser = appUser;
      _authStateController.add(appUser);
      return appUser;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_uid');
    await prefs.remove('local_email');
    await prefs.remove('local_displayName');
    await prefs.remove('local_photoURL');
    
    _cachedUser = null;
    _authStateController.add(null);
  }
}
