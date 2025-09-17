import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

ValueNotifier<AuthService> authService = ValueNotifier(AuthService());

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email/Password Authentication
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  // Google Authentication
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Save user info to Firestore
      await _saveUserToFirestore(userCredential.user!, 'google');
      
      return userCredential;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      rethrow;
    }
  }

  // Facebook Authentication
  Future<UserCredential?> signInWithFacebook() async {
    try {
      // Check if Facebook login is available
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      
      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final OAuthCredential credential = FacebookAuthProvider.credential(accessToken.token);
        
        UserCredential userCredential = await _auth.signInWithCredential(credential);
        
        // Save user info to Firestore
        await _saveUserToFirestore(userCredential.user!, 'facebook');
        
        return userCredential;
      } else if (result.status == LoginStatus.cancelled) {
        throw Exception('CANCELLED');
      } else if (result.status == LoginStatus.failed) {
        throw Exception('Facebook login failed: ${result.message}');
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('Facebook Platform Error: $e');
      if (e.code == 'MissingPluginException') {
        throw Exception('MissingPluginException: Facebook authentication is not properly configured');
      }
      rethrow;
    } catch (e) {
      debugPrint('Facebook Sign In Error: $e');
      rethrow;
    }
  }

  // Phone Authentication
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<UserCredential> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    UserCredential userCredential = await _auth.signInWithCredential(credential);
    
    // Save user info to Firestore
    await _saveUserToFirestore(userCredential.user!, 'phone');
    
    return userCredential;
  }

  // Helper method to save user to Firestore
  Future<void> _saveUserToFirestore(User user, String provider) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL ?? 'https://i.pinimg.com/736x/8b/16/7a/8b167af653c2399dd93b952a48740620.jpg',
          'phoneNumber': user.phoneNumber,
          'provider': provider,
          'role': 'user',
          'address': null,
          'dateOfBirth': null,
          'gender': null,
          'bio': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update last login time
        await _firestore.collection('users').doc(user.uid).update({
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error saving user to Firestore: $e');
    }
  }

  Future<void> signOut() async {
    try {
      User? currentUser = _auth.currentUser;
      
      if (currentUser != null) {
        // Check user's provider to determine which services to sign out from
        List<String> providers = currentUser.providerData.map((info) => info.providerId).toList();
        
        // Sign out from Google if user signed in with Google
        if (providers.contains('google.com')) {
          try {
            await _googleSignIn.signOut();
            debugPrint('✅ Google signOut successful');
          } catch (e) {
            debugPrint('❌ Google signOut error: $e');
          }
        }

        // Sign out from Facebook if user signed in with Facebook
        if (providers.contains('facebook.com')) {
          try {
            await FacebookAuth.instance.logOut();
            debugPrint('✅ Facebook signOut successful');
          } catch (e) {
            debugPrint('❌ Facebook signOut error: $e');
            // Continue with Firebase signOut even if Facebook fails
          }
        }
      }

      // Always sign out from Firebase
      await _auth.signOut();
      debugPrint('✅ Firebase signOut successful');
      
    } catch (e) {
      debugPrint('❌ SignOut error: $e');
      // Even if there's an error, try to sign out from Firebase
      try {
        await _auth.signOut();
      } catch (firebaseError) {
        debugPrint('❌ Firebase signOut error: $firebaseError');
        rethrow;
      }
    }
  }

  Future<void> resetPassword({
    required String email,
  }) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateUserName({
    required String username,
  }) async {
    await currentUser!.updateDisplayName(username);
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    AuthCredential credential =
        EmailAuthProvider.credential(email: email, password: password);
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.delete();
    await _auth.signOut();
  }

  Future<void> resetPasswordFromCurrentPassword({
    required String email,
    required String password,
    required String newPassword,
  }) async {
    try {
      AuthCredential credential =
          EmailAuthProvider.credential(email: email, password: password);

      await FirebaseAuth.instance.currentUser!
          .reauthenticateWithCredential(credential);

      await FirebaseAuth.instance.currentUser!.updatePassword(newPassword);
      print("Password updated successfully!");
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception("Lỗi không xác định: ${e.toString()}");
    }
  }

  Future<Map<String, dynamic>?> getUserInfo() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      print("Lỗi khi lấy thông tin user: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getInfoUserFromEmail(String email) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data() as Map<String, dynamic>;
    } else {
      return null;
    }
  }
}
