import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Signs the current user out of Firebase.
  /// Returns null on success, or an error message string on failure.
  Future<String?> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      return null;
    } catch (e) {
      return 'Logout failed: $e';
    }
  }

  /// Convenience: logout + navigate to a named route, clearing the stack.
  Future<void> logoutAndNavigate(
    BuildContext context, {
    required String routeName,
  }) async {
    final error = await logout();
    if (error != null) return;
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        routeName,
        (route) => false,
      );
    }
  }
}
