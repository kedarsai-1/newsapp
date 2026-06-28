import 'package:flutter/foundation.dart';

/// Holds in-memory choices during the Dailyhunt-style onboarding flow.
/// Persisted when the user taps **Start reading** on the welcome screen.
class OnboardingDraftProvider extends ChangeNotifier {
  String languageCode = 'en';

  /// Category slugs aligned with API (`local`, `politics`, …).
  final Set<String> interestSlugs = {};

  /// Display label for city / region (saved for future locality filters).
  String cityLabel = '';

  double? latitude;
  double? longitude;

  bool notificationsRequested = false;

  void setLanguage(String code) {
    if (languageCode == code) return;
    languageCode = code;
    notifyListeners();
  }

  void toggleInterest(String slug) {
    if (interestSlugs.contains(slug)) {
      interestSlugs.remove(slug);
    } else {
      interestSlugs.add(slug);
    }
    notifyListeners();
  }

  void setCity(String label) {
    cityLabel = label;
    notifyListeners();
  }

  void setCoordinates(double lat, double lng) {
    latitude = lat;
    longitude = lng;
    notifyListeners();
  }

  void setNotificationsRequested(bool value) {
    notificationsRequested = value;
    notifyListeners();
  }

  void reset() {
    languageCode = 'en';
    interestSlugs.clear();
    cityLabel = '';
    latitude = null;
    longitude = null;
    notificationsRequested = false;
    notifyListeners();
  }
}
