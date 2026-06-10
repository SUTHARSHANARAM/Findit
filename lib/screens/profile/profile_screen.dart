import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/post_model.dart';
import '../../providers/post_provider.dart';
import '../../widgets/post_card.dart';
import '../../core/constants/colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final AppUser? _currentUser = AuthService().currentUser;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildPostsList(List<PostModel> posts) {
    if (posts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.post_add_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No items found.',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return PostCard(post: posts[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated.')),
      );
    }

    final String displayName = _currentUser.displayName ?? 'No Name';
    final String email = _currentUser.email ?? 'No Email';
    final String initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                if (!mounted) return;
                Navigator.pop(context); // Close profile screen
                await AuthService().signOut();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // User Info Section
          Container(
            padding: const EdgeInsets.all(24.0),
            color: Colors.white,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: _currentUser.photoURL != null ? NetworkImage(_currentUser.photoURL!) : null,
                  child: _currentUser.photoURL == null
                      ? Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Tab bar for categorizing the user's posts
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'All My Items'),
                Tab(text: 'My Lost Items'),
                Tab(text: 'My Found Items'),
              ],
            ),
          ),
          
          // Tab view content
          Expanded(
            child: Consumer<PostProvider>(
              builder: (context, postProvider, child) {
                if (AuthService().isLocalUser) {
                  final List<PostModel> myPosts = postProvider.posts
                      .where((p) => p.userId == _currentUser.uid)
                      .toList();
                  myPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  final List<PostModel> lostPosts = myPosts.where((p) => p.type == 'lost').toList();
                  final List<PostModel> foundPosts = myPosts.where((p) => p.type == 'found').toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPostsList(myPosts),
                      _buildPostsList(lostPosts),
                      _buildPostsList(foundPosts),
                    ],
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('userId', isEqualTo: _currentUser.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    // Convert docs to PostModel instances
                    final docs = snapshot.data?.docs ?? [];
                    final List<PostModel> myPosts = docs.map((doc) {
                      return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                    }).toList();

                    // Sort posts in-memory to avoid needing composite indexes
                    myPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                    // Filter lists
                    final List<PostModel> lostPosts = myPosts.where((p) => p.type == 'lost').toList();
                    final List<PostModel> foundPosts = myPosts.where((p) => p.type == 'found').toList();

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPostsList(myPosts),
                        _buildPostsList(lostPosts),
                        _buildPostsList(foundPosts),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
