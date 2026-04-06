import 'package:flutter/material.dart';
import '../models/post_model.dart';

class PostProvider with ChangeNotifier {
  // PRO TIP: Safety Toggle! 
  // Set to true once you have run `flutterfire configure`. Default is false to keep dummy data working!
  bool useFirebase = true;

  // Dummy data for V1
  final List<PostModel> _posts = [
    PostModel(
      id: "1",
      title: "Lost Black Wallet",
      description: "Lost my black leather wallet near the central park entrance.",
      type: "lost",
      location: "Central Park Entrance",
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    PostModel(
      id: "2",
      title: "Found Keys",
      description: "Found a bunch of keys with a red keychain near the college gate.",
      type: "found",
      location: "College Gate",
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  List<PostModel> get posts => [..._posts];

  void toggleFirebase(bool value) {
    useFirebase = value;
    notifyListeners();
  }

  void addPost(PostModel post) {
    _posts.insert(0, post); // Add at the top for feed
    notifyListeners();
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
