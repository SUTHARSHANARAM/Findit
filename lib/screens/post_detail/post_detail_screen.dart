import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../models/post_model.dart';
import '../../providers/post_provider.dart';
import '../../widgets/custom_button.dart';
import '../../services/chat_service.dart';
import '../chat/chat_screen.dart';
import '../add_post/add_post_screen.dart';

class PostDetailScreen extends StatelessWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        backgroundColor: "lost" == post.type ? AppColors.lostBadge : AppColors.foundBadge,
        foregroundColor: Colors.white,
        actions: post.userId == ChatService.currentUserId ? [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Edit Item",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => AddPostScreen(existingPost: post),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: "Delete Item",
            onPressed: () async {
              bool? confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Post'),
                  content: const Text('Are you sure you want to permanently delete this post?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              
              if (confirm == true) {
                final provider = Provider.of<PostProvider>(context, listen: false);
                if (provider.useFirebase) {
                  await FirestoreService().deletePost(post.id);
                } else {
                  provider.deletePost(post.id);
                }
                if (!context.mounted) return;
                Navigator.pop(context); // Go back to Home
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item deleted permanently.')));
              }
            },
          ),
        ] : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: post.type == 'lost' 
                        ? AppColors.lostBadge.withAlpha(51) 
                        : AppColors.foundBadge.withAlpha(51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    post.type.toUpperCase(),
                    style: TextStyle(
                      color: post.type == 'lost' ? AppColors.lostBadge : AppColors.foundBadge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (post.isResolved) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
                    child: const Text('RESOLVED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (post.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: post.imageUrl!.startsWith('BASE64:')
                  ? Image.memory(
                      base64Decode(post.imageUrl!.substring(7)),
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                    )
                  : Image.network(
                      post.imageUrl!,
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                  ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              post.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM d, yyyy - h:mm a').format(post.createdAt),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Location',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.location,
                    style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              post.description,
              style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.5),
            ),
            
            const SizedBox(height: 48),
            // Show Mark as Resolved only for the Creator
            if (post.userId == ChatService.currentUserId && !post.isResolved) ...[
              CustomButton(
                text: "Mark as Resolved \u2714",
                onPressed: () async {
                  final provider = Provider.of<PostProvider>(context, listen: false);
                  if (provider.useFirebase) {
                    await FirestoreService().updatePostStatus(post.id, true);
                  } else {
                    provider.updatePostStatus(post.id, true);
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item marked perfectly as resolved!'), backgroundColor: Colors.green),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
            
            // Hide Contact button from the creator themselves
            if (post.userId != ChatService.currentUserId)
              CustomButton(
                text: "Contact ${post.type == 'lost' ? 'Owner' : 'Finder'}",
                onPressed: () async {
                    // Connect to Firestore chat service dynamically
                    final chatId = await ChatService().getOrCreateChatRoom(post.id, post.userId ?? 'mock_owner_789');
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(chatId: chatId, itemTitle: post.title),
                      ),
                    );
                },
              ),
          ],
        ),
      ),
    );
  }
}
