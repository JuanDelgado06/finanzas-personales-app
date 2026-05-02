import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Sign in aborted');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_failed' && (e.message ?? '').contains('ApiException: 10')) {
        throw FirebaseAuthException(
          code: 'google-signin-misconfigured',
          message:
              'Google Sign-In no esta configurado correctamente en Firebase para Android (SHA-1/SHA-256).',
        );
      }
      rethrow;
    }
  }

  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  Future<UserCredential> linkAnonymousWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Sign in aborted');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final current = _auth.currentUser;
      if (current == null) {
        return await _auth.signInWithCredential(credential);
      }

      // If current user is not anonymous, this is effectively a normal sign-in.
      if (!current.isAnonymous) {
        return await _auth.signInWithCredential(credential);
      }

      try {
        return await current.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        // Common case: Google account already exists in Firebase.
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use' ||
            e.code == 'account-exists-with-different-credential') {
          return await _auth.signInWithCredential(credential);
        }
        if (e.code == 'provider-already-linked') {
          return await current.reauthenticateWithCredential(credential);
        }
        rethrow;
      }
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_failed' && (e.message ?? '').contains('ApiException: 10')) {
        throw FirebaseAuthException(
          code: 'google-signin-misconfigured',
          message:
              'Google Sign-In no esta configurado correctamente en Firebase para Android (SHA-1/SHA-256).',
        );
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
