import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void showDevAuthError(
  BuildContext context,
  FirebaseAuthException e, {
  String scope = 'auth',
}) {
  if (!kDebugMode) return;

  final msg =
      '[DEBUG][$scope] code=${e.code}'
      '${e.message == null ? '' : ' | ${e.message}'}';

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
}
