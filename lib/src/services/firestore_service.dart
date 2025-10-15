import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> saveCardData(Map<String, dynamic> data) async {
    await _firestore.collection('cards').add({
      ...data,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getAllCards() {
    return _firestore
        .collection('cards')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
