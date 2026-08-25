// lib/screens/chat/chat_screen.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass.dart';
import '../../utils/image_privacy.dart';

/// In-app chat screen backed by Firestore `chat_messages` collection.
///
/// Firestore path: chat_messages/{patientId}/messages
/// Each document: { text, senderId, timestamp, type ('text'/'image'), imageUrl? }
class ChatScreen extends StatefulWidget {
  final String patientId;
  final String coordinatorName;
  final String? coordinatorPhotoUrl;

  const ChatScreen({
    super.key,
    required this.patientId,
    required this.coordinatorName,
    this.coordinatorPhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  late final CollectionReference _messagesRef;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _messagesRef = FirebaseFirestore.instance
        .collection('chat_messages')
        .doc(widget.patientId)
        .collection('messages');

    // Listen for new messages to auto-scroll
    _subscription = _messagesRef
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((_) {
      // Small delay to let list build first
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage({String? text, String? imageUrl}) async {
    final msg = text?.trim();
    if ((msg == null || msg.isEmpty) && imageUrl == null) return;

    await _messagesRef.add({
      'text': msg ?? '',
      'senderId': widget.patientId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': imageUrl != null ? 'image' : 'text',
      'imageUrl': ?imageUrl,
    });

    _msgController.clear();
  }

  /// audit M-20: safely compute avatar initials, tolerating empty or single
  /// names without crashing on `n[0]` for blank tokens.
  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty);
    if (parts.isEmpty) return 'HP';
    return parts.map((p) => p[0]).take(2).join().toUpperCase();
  }

  Future<void> _pickAndSendImage() async {
    // Photo upload relies on dart:io File via firebaseService.uploadFile,
    // which is skipped on web. Tell the user honestly instead of letting the
    // upload silently fail.
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo upload is available on the mobile app.'),
        ),
      );
      return;
    }

    // audit M-9: capture provider synchronously before any async gap so we
    // don't risk reading a stale BuildContext after picker/upload returns.
    final firebaseService = context.read<AuthProvider>().firebaseService;

    final picked = await ImagePrivacy.pickSanitizedImage(
      _imagePicker,
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 75,
    );
    if (picked == null) return;

    // audit M-9: upload to Firebase Storage so the coordinator can actually
    // open the image. Previously we wrote the local device path, which only
    // resolves on the sender's phone.
    final ts = DateTime.now().millisecondsSinceEpoch;
    final filename = p.basename(picked.path);
    final url = await firebaseService.uploadFile(
      localPath: picked.path,
      storagePath: 'chat/${widget.patientId}/${ts}_$filename',
      contentType: 'image/jpeg',
    );

    if (!mounted) return;

    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Couldn't send photo. Check your connection and try again."),
          backgroundColor: context.hc.error,
        ),
      );
      return;
    }

    await _sendMessage(
      text: '📷 Photo',
      imageUrl: url,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: HousepitalColors.orange,
              backgroundImage: widget.coordinatorPhotoUrl != null
                  ? NetworkImage(widget.coordinatorPhotoUrl!)
                  : null,
              child: widget.coordinatorPhotoUrl == null
                  ? Text(
                      // audit M-20: brittle split/[0]/take(2) crashed on empty
                      // tokens or single-name coordinators — see _initials().
                      _initials(widget.coordinatorName),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.coordinatorName,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Honest response-time promise — we do NOT fabricate live
                  // presence (no green dot, no "Online") for stressed families.
                  Text(
                    'Replies in a few minutes',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.hc.greyLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Message list
          Expanded(child: _buildMessageList()),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _messagesRef
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: HousepitalColors.orange),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64, color: context.hc.divider),
                const SizedBox(height: 12),
                Text(
                  'No messages yet',
                  style: TextStyle(
                      fontSize: 16, color: context.hc.greyLight),
                ),
                const SizedBox(height: 4),
                Text(
                  'Send a message to start the conversation',
                  style: TextStyle(
                      fontSize: 13, color: context.hc.greyLight),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final isSent = data['senderId'] == widget.patientId;
            final text = data['text'] as String? ?? '';
            final type = data['type'] as String? ?? 'text';
            final timestamp = data['timestamp'] as Timestamp?;
            final imageUrl = data['imageUrl'] as String?;

            return _MessageBubble(
              text: text,
              isSent: isSent,
              timestamp: timestamp?.toDate(),
              isImage: type == 'image',
              imageUrl: imageUrl,
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.hc.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Attach photo button
          IconButton(
            onPressed: _pickAndSendImage,
            icon: const Icon(Icons.photo_outlined),
            color: context.hc.greyLight,
          ),

          // Text field
          Expanded(
            child: TextField(
              controller: _msgController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: context.hc.greyLight),
                filled: true,
                fillColor: context.hc.greyLighter,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Send button
          IconButton(
            onPressed: () => _sendMessage(text: _msgController.text),
            style: IconButton.styleFrom(
              backgroundColor: HousepitalColors.orange,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble widget
// ---------------------------------------------------------------------------
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isSent;
  final DateTime? timestamp;
  final bool isImage;
  final String? imageUrl;

  const _MessageBubble({
    required this.text,
    required this.isSent,
    this.timestamp,
    this.isImage = false,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSent
              ? HousepitalColors.orange
              : context.hc.greyLighter,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isSent ? 16 : 4),
            bottomRight: Radius.circular(isSent ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Image thumbnail placeholder
            if (isImage && imageUrl != null)
              Container(
                width: 180,
                height: 140,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: context.hc.divider,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(Icons.image, color: context.hc.greyLight, size: 40),
                ),
              ),

            // Text
            if (text.isNotEmpty)
              Text(
                text,
                style: TextStyle(
                  color: isSent ? Colors.white : context.hc.black,
                  fontSize: 15,
                ),
              ),

            const SizedBox(height: 4),

            // Timestamp + read receipt
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (timestamp != null)
                  Text(
                    _formatTime(timestamp!),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSent
                          ? Colors.white.withValues(alpha: 0.7)
                          : context.hc.greyLight,
                    ),
                  ),
                if (isSent) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
