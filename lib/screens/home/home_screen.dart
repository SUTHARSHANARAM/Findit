import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/post_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/post_model.dart';
import '../../widgets/post_card.dart';
import '../../core/constants/colors.dart';
import '../search/search_screen.dart';
import '../add_post/add_post_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedDistrict = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FindIt', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: "My Profile",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<PostProvider>(
        builder: (context, provider, child) {
          if (provider.useFirebase) {
            return StreamBuilder<List<PostModel>>(
              stream: FirestoreService().getPostsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Firebase Error: ${snapshot.error}'));
                }
                final allPosts = snapshot.data ?? [];
                
                // Extract unique districts
                final districts = ['All', ...allPosts.map((p) => p.district).where((d) => d.isNotEmpty).toSet()];
                
                // Reset selected district if it's no longer in the list (unless it's 'All')
                if (_selectedDistrict != 'All' && !districts.contains(_selectedDistrict)) {
                  _selectedDistrict = 'All';
                }

                final filteredPosts = _selectedDistrict == 'All'
                    ? allPosts
                    : allPosts.where((p) => p.district == _selectedDistrict).toList();

                return Column(
                  children: [
                    if (districts.length > 1)
                      _buildDistrictChips(districts),
                    Expanded(
                      child: filteredPosts.isEmpty
                          ? Center(
                              child: Text(
                                _selectedDistrict == 'All'
                                    ? 'No items found in Cloud. Tap + to add one!'
                                    : 'No items found in $_selectedDistrict.',
                                style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                              ),
                            )
                          : Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 600),
                                child: ListView.builder(
                                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                                  itemCount: filteredPosts.length,
                                  itemBuilder: (context, index) {
                                    return PostCard(post: filteredPosts[index]);
                                  },
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            );
          }

          // Local Dummy Fallback
          final allPosts = provider.posts;
          final districts = ['All', ...allPosts.map((p) => p.district).where((d) => d.isNotEmpty).toSet()];
          
          if (_selectedDistrict != 'All' && !districts.contains(_selectedDistrict)) {
            _selectedDistrict = 'All';
          }

          final filteredPosts = _selectedDistrict == 'All'
              ? allPosts
              : allPosts.where((p) => p.district == _selectedDistrict).toList();
          
          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 1));
            },
            color: AppColors.primary,
            child: Column(
              children: [
                if (districts.length > 1)
                  _buildDistrictChips(districts),
                Expanded(
                  child: filteredPosts.isEmpty
                      ? Center(
                          child: Text(
                            _selectedDistrict == 'All'
                                ? 'No items found locally. Tap + to add one!'
                                : 'No items found in $_selectedDistrict locally.',
                            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                          ),
                        )
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: ListView.builder(
                              padding: const EdgeInsets.only(top: 8, bottom: 80),
                              itemCount: filteredPosts.length,
                              itemBuilder: (context, index) {
                                return PostCard(post: filteredPosts[index]);
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
           Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPostScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Item', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildDistrictChips(List<String> districts) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: districts.map((district) {
            final isSelected = _selectedDistrict == district;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(district == 'All' ? 'All Districts' : district),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedDistrict = district;
                    });
                  }
                },
                selectedColor: AppColors.primary.withOpacity(0.2),
                checkmarkColor: AppColors.primary,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
