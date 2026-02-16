import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountDeletionService {
  // Fast client-side deletion:
  // 1) Re-authenticate
  // 2) Optionally mark deletion request in user doc
  // 3) Delete Firebase Auth user
  //
  // Firestore cleanup is handled by Cloud Functions on auth.user().onDelete.
  static Future<void> deleteCurrentUserCompletely({
    required String password,
  }) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      throw Exception('No signed in user');
    }

    final email = (user.email ?? '').trim().toLowerCase();
    if (email.isEmpty) {
      throw Exception('This account cannot be deleted from app yet.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

    // Best-effort marker so backend can detect intent; do not block delete.
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'deletionRequestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    await user.delete();
  }
}
