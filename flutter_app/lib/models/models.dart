import '../utils/youtube_thumb_url.dart';

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

String _mongoIdFromJson(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is Map) {
    final m = Map<String, dynamic>.from(value);
    final oid = m[r'$oid'] ?? m['oid'];
    if (oid != null) return oid.toString();
  }
  return value.toString();
}

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
        id: _mongoIdFromJson(json['_id'] ?? json['id']),
        name: json['name']?.toString() ?? '',
        slug: json['slug']?.toString() ?? '',
        icon: json['icon']?.toString() ?? '📰',
        color: json['color']?.toString() ?? '#1D9E75',
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
        id: (json['_id'] ?? json['id'] ?? '').toString(),
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
  final String? district;
  final String? mandal;
  final String? state;
  final String country;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.district,
    this.mandal,
    this.state,
    this.country = 'India',
  });

  factory LocationData.fromJson(Map<String, dynamic> json) => LocationData(
        latitude: (json['latitude'] ?? 0).toDouble(),
        longitude: (json['longitude'] ?? 0).toDouble(),
        address: json['address'],
        city: json['city'],
        district: json['district'],
        mandal: json['mandal'],
        state: json['state'],
        country: json['country'] ?? 'India',
      );

  String get displayLocation {
    if (mandal != null && district != null) return '$mandal, $district';
    if (district != null && state != null) return '$district, $state';
    if (city != null && state != null) return '$city, $state';
    if (city != null) return city!;
    if (address != null) return address!;
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }
}

// models/news_post.dart

DateTime? _parseOptionalDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

class YoutubeMeta {
  final String videoId;
  final String? channelTitle;
  final String? channelId;
  final String? watchUrl;
  final String? channelUrl;
  final String? embedUrl;
  final int? durationSeconds;
  final bool isShort;
  final bool embeddable;

  const YoutubeMeta({
    required this.videoId,
    this.channelTitle,
    this.channelId,
    this.watchUrl,
    this.channelUrl,
    this.embedUrl,
    this.durationSeconds,
    this.isShort = false,
    this.embeddable = true,
  });

  factory YoutubeMeta.fromJson(Map<String, dynamic> json) => YoutubeMeta(
        videoId: (json['videoId'] ?? '').toString(),
        channelTitle: json['channelTitle']?.toString(),
        channelId: json['channelId']?.toString(),
        watchUrl: json['watchUrl']?.toString(),
        channelUrl: json['channelUrl']?.toString(),
        embedUrl: json['embedUrl']?.toString(),
        durationSeconds: json['durationSeconds'] is num
            ? (json['durationSeconds'] as num).toInt()
            : int.tryParse(json['durationSeconds']?.toString() ?? ''),
        isShort: json['isShort'] == true,
        embeddable: json['embeddable'] != false,
      );
}

/// Strip ingestion prefixes like `RSS ·` / `YouTube ·` for display.
String? cleanIngestSourceLabel(String? raw) {
  final src = raw?.trim();
  if (src == null || src.isEmpty) return null;
  for (final prefix in ['RSS · ', 'YouTube · ', 'GNews · ', 'NewsAPI · ']) {
    if (src.startsWith(prefix)) return src.substring(prefix.length).trim();
  }
  return src;
}

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
  /// ISO 639-3 from ingest (e.g. tel, hin, eng).
  final String? originalLanguage;
  final String? politicsScope;
  final String? constituency;
  final String? locationDistrict;
  final String? locationMandal;
  final String? sourceUrl;
  final String? sourceName;
  /// API-normalized outlet name (reporter.name is also rewritten for ingested posts).
  final String? publisherName;
  final String? sourceType;
  final YoutubeMeta? youtube;
  /// When the publisher released the story (RSS/API). Prefer over [createdAt] for display.
  final DateTime? sourcePublishedAt;
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
    this.originalLanguage,
    this.politicsScope,
    this.constituency,
    this.locationDistrict,
    this.locationMandal,
    this.sourceUrl,
    this.sourceName,
    this.publisherName,
    this.sourceType,
    this.youtube,
    this.sourcePublishedAt,
    required this.createdAt,
  });

  bool get isYoutube =>
      sourceType == 'youtube' || (youtube != null && youtube!.videoId.isNotEmpty);

  String get youtubeThumbnailUrl {
    final vid = youtube?.videoId;
    final fromMedia = firstVideo?.thumbnail?.trim();
    return YoutubeThumbUrl.fromPost(
          videoId: vid,
          mediaThumbnail: fromMedia,
        ) ??
        '';
  }

  String? get youtubeWatchUrl =>
      youtube?.watchUrl ?? sourceUrl ?? firstVideo?.url;

  String? get youtubeChannelUrl => youtube?.channelUrl;

  String get youtubeChannelLabel =>
      youtube?.channelTitle?.trim().isNotEmpty == true
          ? youtube!.channelTitle!.trim()
          : 'YouTube';

  /// Prefer original publish time so cards don’t all show the same “ingested X ago”.
  DateTime get displayTime => sourcePublishedAt ?? createdAt;

  /// Publisher/outlet for UI — RSS feed, YouTube channel, or human reporter (not ingestion bot).
  String get displaySourceName {
    final pub = publisherName?.trim();
    if (pub != null && pub.isNotEmpty) return pub;
    final cleaned = cleanIngestSourceLabel(sourceName);
    if (cleaned != null && cleaned.isNotEmpty) return cleaned;
    if (isYoutube) return youtubeChannelLabel;
    final reporterName = reporter?.name.trim();
    if (reporterName != null &&
        reporterName.isNotEmpty &&
        reporterName != 'News Ingestion Bot') {
      return reporterName;
    }
    final categoryName = category?.name.trim();
    if (categoryName != null && categoryName.isNotEmpty) return categoryName;
    return 'News';
  }

  String get displaySourceInitial {
    final name = displaySourceName.trim();
    if (name.isEmpty) return 'N';
    return name[0].toUpperCase();
  }

  factory NewsPost.fromJson(Map<String, dynamic> json) => NewsPost(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
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
        originalLanguage: json['originalLanguage']?.toString().toLowerCase(),
        politicsScope: json['politicsScope']?.toString(),
        constituency: json['constituency']?.toString(),
        locationDistrict: json['locationDistrict']?.toString() ??
            (json['location'] is Map
                ? json['location']['district']?.toString()
                : null),
        locationMandal: json['locationMandal']?.toString() ??
            (json['location'] is Map
                ? json['location']['mandal']?.toString()
                : null),
        sourceUrl: json['sourceUrl'],
        sourceName: json['sourceName']?.toString(),
        publisherName: json['publisherName']?.toString(),
        sourceType: json['sourceType']?.toString(),
        youtube: json['youtube'] is Map
            ? YoutubeMeta.fromJson(Map<String, dynamic>.from(json['youtube']))
            : null,
        sourcePublishedAt: _parseOptionalDate(json['sourcePublishedAt']),
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJsonMap() => {
        '_id': id,
        'id': id,
        'title': title,
        'body': body,
        'summary': summary,
        'reporter': reporter != null
            ? {
                '_id': reporter!.id,
                'id': reporter!.id,
                'name': reporter!.name,
                'avatar': reporter!.avatar,
              }
            : null,
        'category': category != null
            ? {
                '_id': category!.id,
                'id': category!.id,
                'name': category!.name,
                'slug': category!.slug,
                'icon': category!.icon,
                'color': category!.color,
              }
            : null,
        'media': media
            .map((m) => {
                  '_id': m.id,
                  'id': m.id,
                  'type': m.type,
                  'url': m.url,
                  'thumbnail': m.thumbnail,
                  'size': m.size,
                })
            .toList(),
        'location': location != null
            ? {
                'latitude': location!.latitude,
                'longitude': location!.longitude,
                'address': location!.address,
                'city': location!.city,
                'state': location!.state,
                'district': location!.district,
                'mandal': location!.mandal,
              }
            : null,
        'status': status,
        'rejectionReason': rejectionReason,
        'views': views,
        'likes': likes,
        'isBreaking': isBreaking,
        'isFeatured': isFeatured,
        'tags': tags,
        'language': language,
        'originalLanguage': originalLanguage,
        'politicsScope': politicsScope,
        'constituency': constituency,
        'locationDistrict': locationDistrict,
        'locationMandal': locationMandal,
        'sourceUrl': sourceUrl,
        'sourceName': sourceName,
        'publisherName': publisherName,
        'sourceType': sourceType,
        'youtube': youtube != null
            ? {
                'videoId': youtube!.videoId,
                'watchUrl': youtube!.watchUrl,
                'channelTitle': youtube!.channelTitle,
                'channelUrl': youtube!.channelUrl,
              }
            : null,
        'sourcePublishedAt': sourcePublishedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  bool get hasImages => media.any((m) => m.isImage && m.url.trim().isNotEmpty);
  bool get hasVideos => media.any((m) => m.isVideo);
  MediaItem? get firstImage {
    for (final m in media) {
      if (m.isImage && m.url.trim().isNotEmpty) return m;
    }
    return null;
  }

  MediaItem? get firstVideo {
    for (final m in media) {
      if (m.isVideo && m.url.trim().isNotEmpty) return m;
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
