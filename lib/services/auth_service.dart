import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'notification_service.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (e) {
      return null;
    }
  }

  Future<String?> signInWithEmail(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Verify Admin role and active status
      final error = await verifyAdminStatus(credential.user?.uid);
      if (error != null) {
        return error;
      }

      // ✅ Register FCM token after successful admin login
      await NotificationService.instance.initialize();

      return null; // Success
    } on FirebaseAuthException catch (e) {
      debugPrint('ERROR CODE: ${e.code}');
      debugPrint('ERROR MESSAGE: ${e.message}');
      return e.message ?? 'An unknown authentication error occurred.';
    } catch (e) {
      return e.toString();
    }
  }

  /// Verifies if the UID belongs to an active admin/super_admin in Firestore
  Future<String?> verifyAdminStatus(String? uid) async {
    if (uid == null) return 'Authentication failed: No user found.';

    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('admins')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final role = data['role'];
        final isActive = data['active'] ?? false;

        if (!isActive) {
          await _auth.signOut();
          return 'Access Denied: Your account is inactive.';
        }

        if (role == 'admin' || role == 'super_admin') {
          return null; // Authorized
        } else {
          await _auth.signOut();
          return 'Access Denied: You do not have admin privileges.';
        }
      } else {
        await _auth.signOut();
        return 'Access Denied: Admin record not found.';
      }
    } catch (e) {
      await _auth.signOut();
      return 'Error verifying admin status: $e';
    }
  }

  Future<void> signOut() async {
    // ✅ Remove FCM token before signing out so device stops receiving alerts
    await NotificationService.instance.removeToken();
    await _auth.signOut();
  }
}
