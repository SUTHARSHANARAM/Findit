import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../services/auth_service.dart';

class ChatService {
  FirebaseFirestore get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      throw Exception("Firestore unavailable");
    }
  }

  // Local storage of mock messages for offline mode
  static final Map<String, List<MessageModel>> _localMessages = {};
  static final Map<String, StreamController<List<MessageModel>>> _localStreamControllers = {};

  // Retrieve the authenticated user's UID dynamically
  static String get currentUserId => AuthService().currentUser?.uid ?? 'guest';

  // Retrieve an existing chat room or create a new deterministic one
  Future<String> getOrCreateChatRoom(String postId, String itemOwnerId) async {
    if (itemOwnerId == currentUserId) return "chat_${postId}_owner";
    
    final chatId = "chat_${postId}_$currentUserId";
    
    if (AuthService().isLocalUser) {
      return chatId;
    }
    
    await _db.collection('chats').doc(chatId).set({
      'postId': postId,
      'user1': itemOwnerId,
      'user2': currentUserId,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    return chatId;
  }

  Stream<List<MessageModel>> getMessagesStream(String chatId) {
    if (AuthService().isLocalUser) {
      final controller = _localStreamControllers.putIfAbsent(chatId, () {
        final c = StreamController<List<MessageModel>>.broadcast();
        c.add(_localMessages[chatId]?.reversed.toList() ?? []);
        return c;
      });
      return controller.stream;
    }

    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> sendMessage(String chatId, String text, {String? imageUrl}) async {
    final message = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: currentUserId,
      text: text,
      imageUrl: imageUrl,
      timestamp: DateTime.now(),
    );

    if (AuthService().isLocalUser) {
      _localMessages.putIfAbsent(chatId, () => []).add(message);
      _localStreamControllers[chatId]?.add(_localMessages[chatId]!.reversed.toList());
      return;
    }

    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message.toMap());
        
    await _db.collection('chats').doc(chatId).update({
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
