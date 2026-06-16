// ============================================================
// COMMENTS SHEET
// A bottom sheet that shows all comments on a transaction
// and allows users to add new ones.
//
// Features:
//   - Real-time comment stream (updates live as others comment)
//   - Any user can add a comment
//   - Manager can delete any comment (long press)
//   - Shows author name, role badge, and timestamp
//   - Keyboard-aware — sheet rises above keyboard when typing
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/comment_service.dart';

class CommentsSheet extends StatefulWidget {
  final String transactionId;   // Firestore doc ID of the transaction
  final String transactionInfo; // Short description shown in header
  final String collection;      // Which collection ('sales', 'stock_in', etc.)
  final UserModel user;         // Currently logged-in user

  const CommentsSheet({
    super.key,
    required this.transactionId,
    required this.transactionInfo,
    required this.collection,
    required this.user,
  });

  /// Convenience method to open this sheet from anywhere.
  static Future<void> show(
      BuildContext context, {
        required String transactionId,
        required String transactionInfo,
        required String collection,
        required UserModel user,
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to expand when keyboard opens
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        transactionId: transactionId,
        transactionInfo: transactionInfo,
        collection: collection,
        user: user,
      ),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _commentController = TextEditingController();
  final _commentService = CommentService();
  bool _isSubmitting = false;

  // Role badge colors for visual identification
  Color _roleColor(String role) {
    switch (role) {
      case 'manager': return Colors.blue.shade700;
      case 'cashier': return Colors.green.shade700;
      case 'stock_rep': return const Color(0xFF1565C0);
      case 'backup': return const Color(0xFF00695C);
      case 'view_only': return Colors.purple.shade700;
      default: return Colors.grey;
    }
  }

  // Human-readable role labels
  String _roleLabel(String role) {
    switch (role) {
      case 'manager': return 'Manager';
      case 'cashier': return 'Cashier';
      case 'stock_rep': return 'Stock Rep';
      case 'backup': return 'Backup Rep';
      case 'view_only': return 'Management';
      default: return 'Staff';
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    await _commentService.addComment(
      transactionId: widget.transactionId,
      collection: widget.collection,
      text: text,
      authorName: widget.user.name,
      authorRole: widget.user.role,
    );

    _commentController.clear();
    setState(() => _isSubmitting = false);
  }

  void _confirmDelete(BuildContext ctx, String commentId,
      String authorName) {
    // Only manager can delete comments
    if (!widget.user.isManager) return;

    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Comment?'),
        content: Text('Delete $authorName\'s comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () async {
              await _commentService.deleteComment(commentId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sheet takes up 75% of screen height, more when keyboard is open
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.comment,
                      color: Color(0xFF0D47A1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text('Comments',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17)),
                        Text(widget.transactionInfo,
                            style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
              ),
              const Divider(height: 1),

              // Comments list — live updating via StreamBuilder
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _commentService
                      .getCommentsStream(widget.transactionId),
                  builder: (context, snap) {
                    // Loading state
                    if (snap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final docs = snap.data?.docs ?? [];

                    // Empty state
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 48,
                                color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('No comments yet.',
                                style: TextStyle(
                                    color: Colors.grey)),
                            const Text(
                                'Be the first to add one.',
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12)),
                          ],
                        ),
                      );
                    }

                    // Comments list
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i].data()
                        as Map<String, dynamic>;
                        final commentId = docs[i].id;
                        final authorName =
                            d['authorName'] ?? 'Unknown';
                        final authorRole = d['authorRole'] ?? '';
                        final text = d['text'] ?? '';
                        final timestamp =
                        d['createdAt'] as Timestamp?;
                        final timeStr = timestamp != null
                            ? DateFormat('MMM d, h:mm a')
                            .format(timestamp.toDate())
                            : '';

                        // Check if this comment belongs to current user
                        final isMyComment =
                            d['authorName'] == widget.user.name;

                        return GestureDetector(
                          // Long press to delete (manager only)
                          onLongPress: widget.user.isManager
                              ? () => _confirmDelete(
                              context, commentId, authorName)
                              : null,
                          child: Container(
                            margin:
                            const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                // Avatar
                                CircleAvatar(
                                  backgroundColor: _roleColor(
                                      authorRole)
                                      .withOpacity(0.15),
                                  radius: 18,
                                  child: Text(
                                    authorName.isNotEmpty
                                        ? authorName[0]
                                        .toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color:
                                      _roleColor(authorRole),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Comment bubble
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      // Author name + role badge + time
                                      Row(children: [
                                        Text(
                                          isMyComment
                                              ? 'You'
                                              : authorName,
                                          style: const TextStyle(
                                              fontWeight:
                                              FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 6,
                                              vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _roleColor(
                                                authorRole)
                                                .withOpacity(0.1),
                                            borderRadius:
                                            BorderRadius
                                                .circular(4),
                                          ),
                                          child: Text(
                                            _roleLabel(authorRole),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: _roleColor(
                                                  authorRole),
                                              fontWeight:
                                              FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(timeStr,
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 10)),
                                      ]),
                                      const SizedBox(height: 4),

                                      // Comment text bubble
                                      Container(
                                        padding:
                                        const EdgeInsets.all(
                                            10),
                                        decoration: BoxDecoration(
                                          color: isMyComment
                                              ? const Color(
                                              0xFF0D47A1)
                                              .withOpacity(0.08)
                                              : Colors.grey
                                              .shade100,
                                          borderRadius:
                                          BorderRadius.circular(
                                              10),
                                        ),
                                        child: Text(text,
                                            style: const TextStyle(
                                                fontSize: 14)),
                                      ),

                                      // Delete hint for manager
                                      if (widget.user.isManager)
                                        Padding(
                                          padding:
                                          const EdgeInsets.only(
                                              top: 2),
                                          child: Text(
                                            'Hold to delete',
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.grey
                                                    .shade400),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Comment input — stays above keyboard
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom +
                      16,
                  top: 8,
                ),
                child: Row(children: [
                  // Input field
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization:
                      TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submitComment,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D47A1),
                        shape: BoxShape.circle,
                      ),
                      child: _isSubmitting
                          ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2))
                          : const Icon(Icons.send,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}