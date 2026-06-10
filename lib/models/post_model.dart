class PostModel {
  final String id;
  final String title;
  final String description;
  final String type; // "lost" or "found"
  final String location;
  final String district;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final DateTime createdAt;
  final String? userId; // For later
  final bool isResolved;

  PostModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.location,
    this.district = '',
    this.latitude,
    this.longitude,
    this.imageUrl,
    required this.createdAt,
    this.userId,
    this.isResolved = false,
  });

  // Factory constructor to create from Firebase later
  factory PostModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PostModel(
      id: documentId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'lost',
      location: map['location'] ?? '',
      district: map['district'] ?? '',
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      imageUrl: map['imageUrl'],
      createdAt: DateTime.parse(map['createdAt']), // Example conversion
      userId: map['userId'],
      isResolved: map['isResolved'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type,
      'location': location,
      'district': district,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'userId': userId,
      'isResolved': isResolved,
    };
  }
}
