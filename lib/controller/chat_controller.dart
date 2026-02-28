import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  Future<void> clearChat() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(
            'your_collection_name',
          ) // ← replace with your actual collection name
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      log("clearChat error: $e");
    }
  }

//   Future<void> _clearAllMessages() async {
//   setState(() => _isClearing = true);
//   try {
//     final snap = await _chatsRef.get();
//     final batch = FirebaseFirestore.instance.batch();
//     for (final doc in snap.docs) {
//       batch.delete(doc.reference);
//     }
//     await batch.commit();
//   } catch (e) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to clear: $e'), backgroundColor: Colors.redAccent),
//       );
//     }
//   } finally {
//     if (mounted) setState(() => _isClearing = false);
//   }
// }

// void _confirmClear() {
//   showDialog(
//     context: context,
//     builder: (ctx) => AlertDialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       title: const Row(
//         children: [
//           Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 22),
//           SizedBox(width: 8),
//           Text('Clear Chat', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
//         ],
//       ),
//       content: const Text(
//         'This will permanently delete all messages from Firebase. This cannot be undone.',
//         style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.5),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(ctx),
//           child: const Text('Cancel', style: TextStyle(color: Color(0xFF9CA3AF))),
//         ),
//         ElevatedButton(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.redAccent,
//             foregroundColor: Colors.white,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//             elevation: 0,
//           ),
//           onPressed: () async {
//             Navigator.pop(ctx);
//             await _clearAllMessages();
//             if (mounted) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text('Chat cleared successfully'),
//                   backgroundColor: Colors.redAccent,
//                   duration: Duration(seconds: 2),
//                 ),
//               );
//             }
//           },
//           child: const Text('Clear'),
//         ),
//       ],
//     ),
//   );
// }
}
