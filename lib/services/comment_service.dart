// ============================================================
// COMMENT SERVICE
// Handles all comment operations for transaction records.
//
// Comments are stored in a top-level 'comments' collection.
// Each comment links to a transaction via transactionId.
//
// Any logged-in user can read and add comments.
// Only managers can delete comments.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class CommentService {
  final _db = FirebaseFirestore.instance;

  /// Adds a comment to a specific transaction.
  /// [transactionId] is the Firestore document ID of the transaction.
  /// [collection] is which collection it belongs to (sales, stock_in, etc.)
  Future<void> addComment({
    required String transactionId,
    required String collection,
    required String text,
    required String authorName,
    required String authorRole,
  }) async {
    await _db.collection('comments').add({
      'transactionId': transactionId,
      'collection': collection,   // e.g. 'sales', 'stock_in', 'returns'
      'text': text.trim(),
      'authorName': authorName,
      'authorRole': authorRole,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Real-time stream of all comments for a transaction, oldest first.
  Stream<QuerySnapshot> getCommentsStream(String transactionId) {
    return _db
        .collection('comments')
        .where('transactionId', isEqualTo: transactionId)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Deletes a comment by its Firestore document ID.
  /// Only callable by manager role (enforced in the UI).
  Future<void> deleteComment(String commentId) async {
    await _db.collection('comments').doc(commentId).delete();
  }
}