import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Retrieve the authenticated user's UID dynamically
  static String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  // Retrieve an existing chat room or create a new deterministic one
  Future<String> getOrCreateChatRoom(String postId, String itemOwnerId) async {
    if (itemOwnerId == currentUserId) return "chat_${postId}_owner";
    
    final chatId = "chat_${postId}_$currentUserId";
    
    await _db.collection('chats').doc(chatId).set({
      'postId': postId,
      'user1': itemOwnerId,
      'user2': currentUserId,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    return chatId;
  }

  Stream<List<MessageModel>> getMessagesStream(String chatId) {
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
      id: '',
      senderId: currentUserId,
      text: text,
      imageUrl: imageUrl,
      timestamp: DateTime.now(),
    );

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
