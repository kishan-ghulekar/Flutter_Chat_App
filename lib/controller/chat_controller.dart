import 'package:cloud_firestore/cloud_firestore.dart';

class ChatController {
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;

  //SEND MESSAGE

  Future<void> updateMessage({
    required String docId,
    required Map<String, dynamic> messageUpdateBody,
  }) async {
    await _firebaseFirestore
        .collection("ChatData")
        .doc(docId)
        .update(messageUpdateBody);
  }

  Future<void> sendMessage({required Map<String, dynamic> messageBody}) async {
    await _firebaseFirestore.collection("ChatData").add(messageBody);
  }

  Future<void> deleteMessage({required String docId}) async {
    await _firebaseFirestore.collection("ChatData").doc(docId).delete();
  }

  Stream<QuerySnapshot> getMessages() {
    return _firebaseFirestore
        .collection("ChatData")
        .orderBy("time", descending: false)
        .snapshots();
  }
}
