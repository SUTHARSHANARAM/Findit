import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/auth_service.dart';

class PostProvider with ChangeNotifier {
  bool _useFirebase = true;

  // Getter checks both the toggle AND whether we are signed in as a local user!
  bool get useFirebase => _useFirebase && !AuthService().isLocalUser;

  // Dummy data for V1
  final List<PostModel> _posts = [
    PostModel(
      id: "1",
      title: "Lost Black Wallet",
      description: "Lost my black leather wallet near the central park entrance.",
      type: "lost",
      location: "Central Park Entrance",
      district: "Central District",
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      userId: 'local_google_user',
    ),
    PostModel(
      id: "2",
      title: "Found Keys",
      description: "Found a bunch of keys with a red keychain near the college gate.",
      type: "found",
      location: "College Gate",
      district: "North District",
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      userId: 'other_user',
    ),
  ];

  List<PostModel> get posts => [..._posts];

  void toggleFirebase(bool value) {
    _useFirebase = value;
    notifyListeners();
  }

  void addPost(PostModel post) {
    _posts.insert(0, post); // Add at the top for feed
    notifyListeners();
  }

  void updatePost(PostModel post) {
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index != -1) {
      _posts[index] = post;
      notifyListeners();
    }
  }

  void deletePost(String id) {
    _posts.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void updatePostStatus(String id, bool isResolved) {
    final index = _posts.indexWhere((p) => p.id == id);
    if (index != -1) {
      final p = _posts[index];
      _posts[index] = PostModel(
        id: p.id,
        title: p.title,
        description: p.description,
        type: p.type,
        location: p.location,
        district: p.district,
        latitude: p.latitude,
        longitude: p.longitude,
        imageUrl: p.imageUrl,
        createdAt: p.createdAt,
        userId: p.userId,
        isResolved: isResolved,
      );
      notifyListeners();
    }
  }

  // Search feature implementation
  List<PostModel> searchPosts(String query) {
    if (query.isEmpty) return [..._posts];
    return _posts.where((post) =>
        post.title.toLowerCase().contains(query.toLowerCase()) ||
        post.description.toLowerCase().contains(query.toLowerCase())).toList();
  }

  // Filter implementation
  List<PostModel> filterPosts(String type) {
    if (type.isEmpty || type == 'all') return [..._posts];
    return _posts.where((post) => post.type == type).toList();
  }
}
