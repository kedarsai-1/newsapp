// models/user.dart
class User {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin' | 'reporter' | 'user'
  final String? avatar;
  final String? phone;
  final String? bio;
  final bool isActive;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatar,
    this.phone,
    this.bio,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['_id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        role: json['role'] ?? 'user',
        avatar: json['avatar'],
        phone: json['phone'],
        bio: json['bio'],
        isActive: json['isActive'] ?? true,
      );

  bool get isAdmin => role == 'admin';
  bool get isReporter => role == 'reporter';
  bool get isUser => role == 'user';
}

// models/category.dart
class Category {
  final String id;
  final String name;
  final String slug;
  final String icon;
  final String color;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    required this.color,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['_id'] ?? '',
        name: json['name'] ?? '',
        slug: json['slug'] ?? '',
        icon: json['icon'] ?? '📰',
        color: json['color'] ?? '#1D9E75',
      );
}

// models/media_item.dart
class MediaItem {
  final String id;
  final String type; // 'image' | 'video'
  final String url;
  final String? thumbnail;
  final int size;

  MediaItem({
    required this.id,
    required this.type,
    required this.url,
    this.thumbnail,
    this.size = 0,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['_id'] ?? '',
        type: json['type'] ?? 'image',
        url: json['url'] ?? '',
        thumbnail: json['thumbnail'],
        size: json['size'] ?? 0,
      );

  bool get isVideo => type == 'video';
  bool get isImage => type == 'image';
}

// models/location_data.dart
class LocationData {
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? state;
  final String country;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.state,
    this.country = 'India',
  });

  factory LocationData.fromJson(Map<String, dynamic> json) => LocationData(
        latitude: (json['latitude'] ?? 0).toDouble(),
        longitude: (json['longitude'] ?? 0).toDouble(),
        address: json['address'],
        city: json['city'],
        state: json['state'],
        country: json['country'] ?? 'India',
      );

  String get displayLocation {
    if (city != null && state != null) return '$city, $state';
    if (city != null) return city!;
    if (address != null) return address!;
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }
}

// models/news_post.dart
class NewsPost {
  final String id;
  final String title;
  final String body;
  final String? summary;
  final User? reporter;
  final Category? category;
  final List<MediaItem> media;
  final LocationData? location;
  final String status;
  final String? rejectionReason;
  final int views;
  final int likes;
  final bool isBreaking;
  final bool isFeatured;
  final List<String> tags;
  final String language;
  final String? constituency;
  final String? sourceUrl;
  final String? sourceName;
  final DateTime createdAt;

  NewsPost({
    required this.id,
    required this.title,
    required this.body,
    this.summary,
    this.reporter,
    this.category,
    this.media = const [],
    this.location,
    required this.status,
    this.rejectionReason,
    this.views = 0,
    this.likes = 0,
    this.isBreaking = false,
    this.isFeatured = false,
    this.tags = const [],
    this.language = 'en',
    this.constituency,
    this.sourceUrl,
    this.sourceName,
    required this.createdAt,
  });

  factory NewsPost.fromJson(Map<String, dynamic> json) => NewsPost(
        id: json['_id'] ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        summary: json['summary'],
        reporter:
            json['reporter'] is Map ? User.fromJson(json['reporter']) : null,
        category: json['category'] is Map
            ? Category.fromJson(json['category'])
            : null,
        media: (json['media'] as List? ?? [])
            .map((m) => MediaItem.fromJson(m))
            .toList(),
        location: json['location'] != null
            ? LocationData.fromJson(json['location'])
            : null,
        status: json['status'] ?? 'pending',
        rejectionReason: json['rejectionReason'],
        views: json['views'] ?? 0,
        likes: json['likes'] ?? 0,
        isBreaking: json['isBreaking'] ?? false,
        isFeatured: json['isFeatured'] ?? false,
        tags: List<String>.from(json['tags'] ?? []),
        language: (json['language'] ?? 'en').toString().toLowerCase(),
        constituency: json['constituency']?.toString(),
        sourceUrl: json['sourceUrl'],
        sourceName: json['sourceName']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );

  bool get hasImages => media.any((m) => m.isImage && m.url.trim().isNotEmpty);
  bool get hasVideos => media.any((m) => m.isVideo);
  MediaItem? get firstImage {
    for (final m in media) {
      if (m.isImage && m.url.trim().isNotEmpty) return m;
    }
    return null;
  }
}

// models/comment.dart
class Comment {
  final String id;
  final User? user;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    this.user,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['_id'] ?? '',
        user: json['user'] is Map ? User.fromJson(json['user']) : null,
        text: json['text'] ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}
