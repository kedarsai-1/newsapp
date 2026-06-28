import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import 'feed_xpresso_theme.dart';

/// Compact weather strip for the feed — uses onboarding city or Hyderabad default.
class FeedWeatherBanner extends StatefulWidget {
  const FeedWeatherBanner({super.key});

  @override
  State<FeedWeatherBanner> createState() => _FeedWeatherBannerState();
}

class _FeedWeatherBannerState extends State<FeedWeatherBanner> {
  Map<String, dynamic>? _weather;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool refresh = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      if (refresh) _error = null;
    });

    final news = context.read<NewsProvider>();
    final city = news.preferredCity?.trim().isNotEmpty == true
        ? news.preferredCity!.trim()
        : 'Hyderabad';

    final res = await ApiService.getWeather(city: city, refresh: refresh);

    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _weather = Map<String, dynamic>.from(res);
        _error = null;
        _loading = false;
      });
    } else {
      setState(() {
        _error = res['message']?.toString() ?? 'Weather unavailable';
        _loading = false;
      });
    }
  }

  IconData _iconFor(String? icon) {
    switch (icon) {
      case 'clear':
        return Icons.wb_sunny_outlined;
      case 'partly-cloudy':
        return Icons.wb_cloudy_outlined;
      case 'cloudy':
        return Icons.cloud_outlined;
      case 'fog':
        return Icons.foggy;
      case 'drizzle':
      case 'rain':
        return Icons.grain;
      case 'snow':
        return Icons.ac_unit;
      case 'thunderstorm':
        return Icons.thunderstorm_outlined;
      default:
        return Icons.wb_sunny_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);

    if (_loading && _weather == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: fx.iconSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: fx.divider.withValues(alpha: 0.6)),
          ),
          alignment: Alignment.center,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fx.accent),
          ),
        ),
      );
    }

    if (_weather == null) {
      if (_error == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Material(
          color: fx.iconSurface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _load(refresh: true),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.cloud_off_outlined, color: fx.actionMuted, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: fx.actionMuted, fontSize: 13),
                    ),
                  ),
                  Icon(Icons.refresh_rounded, color: fx.accent, size: 18),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final location = _weather!['location'] is Map
        ? Map<String, dynamic>.from(_weather!['location'] as Map)
        : const <String, dynamic>{};
    final current = _weather!['current'] is Map
        ? Map<String, dynamic>.from(_weather!['current'] as Map)
        : const <String, dynamic>{};
    final city = location['city']?.toString() ?? 'Your city';
    final temp = current['temperatureC'];
    final condition = current['condition']?.toString() ?? '—';
    final humidity = current['humidityPercent'];
    final icon = _iconFor(current['icon']?.toString());

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Material(
        color: fx.iconSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _load(refresh: true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: fx.divider.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Icon(icon, color: fx.accent, size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        city,
                        style: TextStyle(
                          color: fx.iconFg,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        condition,
                        style: TextStyle(color: fx.actionMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (temp != null)
                  Text(
                    '${temp is num ? temp.round() : temp}°C',
                    style: TextStyle(
                      color: fx.iconFg,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                if (humidity != null) ...[
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(Icons.water_drop_outlined, size: 16, color: fx.actionMuted),
                      Text(
                        '${humidity is num ? humidity.round() : humidity}%',
                        style: TextStyle(color: fx.actionMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
