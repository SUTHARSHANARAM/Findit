import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/colors.dart';
import '../../models/post_model.dart';
import '../../providers/post_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/custom_button.dart';

class AddPostScreen extends StatefulWidget {
  final PostModel? existingPost;

  const AddPostScreen({super.key, this.existingPost});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _districtController = TextEditingController();
  
  String _selectedType = 'lost';
  bool _isLoading = false;
  
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    if (widget.existingPost != null) {
      _titleController.text = widget.existingPost!.title;
      _descController.text = widget.existingPost!.description;
      _locationController.text = widget.existingPost!.location;
      _districtController.text = widget.existingPost!.district;
      _selectedType = widget.existingPost!.type;
      _latitude = widget.existingPost!.latitude;
      _longitude = widget.existingPost!.longitude;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    // We aggressively compress the image so it fits inside the free 1MB Firestore Database limit!
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 30, // Compress quality
      maxWidth: 800,    // Shrink size
    );
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location disabled')));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fetching exact GPS...')));
    Position position = await Geolocator.getCurrentPosition();
    
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _locationController.text = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final provider = Provider.of<PostProvider>(context, listen: false);
      
      try {
        String? imageUrl = widget.existingPost?.imageUrl;
        if (_selectedImage != null && provider.useFirebase) {
          imageUrl = await StorageService().uploadImage(_selectedImage!);
        }
        
        final newPost = PostModel(
          id: widget.existingPost?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          type: _selectedType,
          location: _locationController.text.trim(),
          district: _districtController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          imageUrl: imageUrl,
          createdAt: widget.existingPost?.createdAt ?? DateTime.now(),
          userId: widget.existingPost?.userId ?? ChatService.currentUserId,
          isResolved: widget.existingPost?.isResolved ?? false,
        );

        if (provider.useFirebase) {
          if (widget.existingPost == null) {
            await FirestoreService().addPost(newPost).timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw Exception("Firestore took too long to respond. Check if your database is enabled."),
            );
          } else {
            await FirestoreService().updatePost(newPost).timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw Exception("Firestore took too long to respond."),
            );
          }
          if (!mounted) return;
          setState(() => _isLoading = false);
          Navigator.pop(context);
        } else {
          // Fallback dummy save
          await Future.delayed(const Duration(seconds: 1));
          if (widget.existingPost == null) {
            provider.addPost(newPost);
          } else {
            provider.updatePost(newPost);
          }
          if (!mounted) return;
          setState(() => _isLoading = false);
          Navigator.pop(context);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action Failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingPost == null ? 'Add Item' : 'Edit Item'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What happened?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(value: 'lost', label: Text('I lost something')),
                    ButtonSegment<String>(value: 'found', label: Text('I found something')),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _selectedType = newSelection.first;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FutureBuilder<Uint8List>(
                            future: _selectedImage!.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                return Image.memory(snapshot.data!, fit: BoxFit.cover, width: double.infinity);
                              }
                              return const Center(child: CircularProgressIndicator());
                            },
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Tap to add photo', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Please enter item name' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location (landmark, street name...)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Please enter a location' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    color: AppColors.primary,
                    tooltip: "Use Live GPS",
                  )
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _districtController,
                decoration: const InputDecoration(
                  labelText: 'District / Region (e.g. Chennai, Manhattan)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Please enter a district or region' : null,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security_outlined, color: Colors.blue.shade800, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Safety Tip: Do not write down highly unique details (like serial numbers or inner contents) in the description. Keep these secret to verify claims in chat.',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description (color, brand, general details...)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (val) => val == null || val.isEmpty ? 'Please enter description' : null,
              ),
              const SizedBox(height: 32),
              CustomButton(
                text: widget.existingPost == null ? 'Submit Post' : 'Save Changes',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}
