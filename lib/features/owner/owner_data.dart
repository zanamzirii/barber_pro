import 'package:cloud_firestore/cloud_firestore.dart';

Future<String> resolveShopId(String uid) async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  final data = snap.data();
  final shopId = (data?['shopId'] as String?)?.trim();
  if (shopId != null && shopId.isNotEmpty) {
    return shopId;
  }
  return uid;
}

Future<String> resolveAndEnsureShopId(String uid) async {
  final shopId = await resolveShopId(uid);
  final shopRef = FirebaseFirestore.instance.collection('shops').doc(shopId);
  await shopRef.set({
    'shopId': shopId,
    'ownerId': uid,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  return shopId;
}
