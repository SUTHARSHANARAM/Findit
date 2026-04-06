import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get a stream of all posts, ordered by latest
  Stream<List<PostModel>> getPostsStream() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Add a new post to Firestore
  Future<void> addPost(PostModel post) async {
    try {
      await _db.collection('posts').doc(post.id).set(post.toMap());
    } catch (e) {
      throw Exception('Failed to add post: $e');
    }
  }

  // Update post resolution status
  Future<void> updatePostStatus(String id, bool isResolved) async {
    try {
      await _db.collection('posts').doc(id).update({'isResolved': isResolved});
    } catch (e) {
      throw Exception('Failed to update status: $e');
    }
  }

  // Delete the current post
  Future<void> deletePost(String id) async {
    try {
      await _db.collection('posts').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete item: $e');
    }
  }

  // Update a post fully via the Editor
  Future<void> updatePost(PostModel updatedPost) async {
    try {
      await _db.collection('posts').doc(updatedPost.id).update(updatedPost.toMap());
    } catch (e) {
      throw Exception('Failed to update post: $e');
    }
  }
}
