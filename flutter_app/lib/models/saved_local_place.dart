import 'dart:convert';

/// User's saved hyperlocal place (Way2News-style dual locations).
class SavedLocalPlace {
  final String label;
  final String? city;
  final String? district;
  final String? mandal;
  final String? state;
  final double? latitude;
  final double? longitude;

  const SavedLocalPlace({
    this.label = 'Home',
    this.city,
    this.district,
    this.mandal,
    this.state,
    this.latitude,
    this.longitude,
  });

  bool get isEmpty =>
      (city == null || city!.trim().isEmpty) &&
      (district == null || district!.trim().isEmpty) &&
      (mandal == null || mandal!.trim().isEmpty);

  String get displayTitle {
    if (mandal != null && mandal!.trim().isNotEmpty) {
      final d = district?.trim();
      return d != null && d.isNotEmpty ? '$mandal, $d' : mandal!.trim();
    }
    if (city != null && city!.trim().isNotEmpty) return city!.trim();
    if (district != null && district!.trim().isNotEmpty) return district!.trim();
    return label;
  }

  String get shortChipLabel => label.trim().isEmpty ? displayTitle : label.trim();

  Map<String, dynamic> toJson() => {
        'label': label,
        if (city != null) 'city': city,
        if (district != null) 'district': district,
        if (mandal != null) 'mandal': mandal,
        if (state != null) 'state': state,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  factory SavedLocalPlace.fromJson(Map<String, dynamic> json) => SavedLocalPlace(
        label: json['label']?.toString().trim().isNotEmpty == true
            ? json['label'].toString().trim()
            : 'Home',
        city: json['city']?.toString(),
        district: json['district']?.toString(),
        mandal: json['mandal']?.toString(),
        state: json['state']?.toString(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  static SavedLocalPlace? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return SavedLocalPlace.fromJson(map);
      }
    } catch (_) {}
    return null;
  }

  static String encode(SavedLocalPlace place) => jsonEncode(place.toJson());

  SavedLocalPlace copyWith({
    String? label,
    String? city,
    String? district,
    String? mandal,
    String? state,
    double? latitude,
    double? longitude,
  }) =>
      SavedLocalPlace(
        label: label ?? this.label,
        city: city ?? this.city,
        district: district ?? this.district,
        mandal: mandal ?? this.mandal,
        state: state ?? this.state,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );
}
