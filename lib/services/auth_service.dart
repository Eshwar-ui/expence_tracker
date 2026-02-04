import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Store or update user in Firestore
  Future<void> _storeUserInFirestore(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      final now = DateTime.now();

      if (!docSnapshot.exists) {
        // Create new user document
        final appUser = AppUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoURL: user.photoURL,
          createdAt: now,
          lastLoginAt: now,
        );
        await userDoc.set(appUser.toMap());
      } else {
        // Update last login time
        await userDoc.update({
          'lastLoginAt': Timestamp.fromDate(now),
          'displayName': user.displayName,
          'photoURL': user.photoURL,
        });
      }
    } catch (e) {
      // Log error but don't throw - user can still use the app
      print('Error storing user in Firestore: $e');
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null; // User cancelled the sign-in
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Store user details in Firestore
      if (userCredential.user != null) {
        await _storeUserInFirestore(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store user details in Firestore
      if (userCredential.user != null) {
        await _storeUserInFirestore(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      throw Exception('Email sign-in failed: $e');
    }
  }

  // Create account with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store user details in Firestore
      if (userCredential.user != null) {
        await _storeUserInFirestore(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      throw Exception('Account creation failed: $e');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Password reset email failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final uid = currentUser?.uid;
      if (uid != null) {
        // Delete user document from Firestore
        await _firestore.collection('users').doc(uid).delete();
      }
      await currentUser?.delete();
    } catch (e) {
      throw Exception('Account deletion failed: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      await currentUser?.updateDisplayName(displayName);
      await currentUser?.updatePhotoURL(photoURL);

      // Update in Firestore as well
      if (currentUser != null) {
        await _storeUserInFirestore(currentUser!);
      }
    } catch (e) {
      throw Exception('Profile update failed: $e');
    }
  }

  // Get user from Firestore
  Future<AppUser?> getUserFromFirestore(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting user from Firestore: $e');
      return null;
    }
  }

  // Get user display name
  String? get userDisplayName => currentUser?.displayName;

  // Get user email
  String? get userEmail => currentUser?.email;

  // Get user photo URL
  String? get userPhotoURL => currentUser?.photoURL;

  // Check if user is signed in
  bool get isSignedIn => currentUser != null;
}
