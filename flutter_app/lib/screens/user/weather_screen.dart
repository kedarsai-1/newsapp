import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import '../../utils/i18n.dart';
import '../../widgets/dailyhunt/xpresso_sliver_app_bar.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Live weather for the user's city (Open-Meteo via backend).
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
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
    final state = news.activeSavedLocation?.state?.trim();

    final res = await ApiService.getWeather(
      city: city,
      state: state?.isNotEmpty == true ? state : null,
      refresh: refresh,
    );

    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _weather = Map<String, dynamic>.from(res);
        _error = null;
        _loading = false;
      });
    } else {
      setState(() {
        _error = res['message']?.toString() ?? I18n.t(context, 'weather_unavailable');
        _loading = false;
      });
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/feed');
  }

  IconData _iconFor(String? icon) {
    switch (icon) {
      case 'clear':
        return Icons.wb_sunny_rounded;
      case 'partly-cloudy':
        return Icons.wb_cloudy_rounded;
      case 'cloudy':
        return Icons.cloud_rounded;
      case 'fog':
        return Icons.foggy;
      case 'drizzle':
      case 'rain':
        return Icons.grain_rounded;
      case 'snow':
        return Icons.ac_unit_rounded;
      case 'thunderstorm':
        return Icons.thunderstorm_rounded;
      default:
        return Icons.wb_sunny_rounded;
    }
  }

  String _formatDay(String? iso) {
    if (iso == null || iso.length < 10) return '—';
    try {
      final d = DateTime.parse(iso);
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[d.weekday - 1];
    } catch (_) {
      return iso.substring(5, 10);
    }
  }

  String _formatHour(String? iso) {
    if (iso == null || iso.length < 16) return '—';
    try {
      final d = DateTime.parse(iso);
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final ampm = d.hour >= 12 ? 'PM' : 'AM';
      return '$h $ampm';
    } catch (_) {
      return iso.substring(11, 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final location = _weather?['location'] is Map
        ? Map<String, dynamic>.from(_weather!['location'] as Map)
        : const <String, dynamic>{};
    final current = _weather?['current'] is Map
        ? Map<String, dynamic>.from(_weather!['current'] as Map)
        : const <String, dynamic>{};
    final daily = (_weather?['daily'] as List?) ?? const [];
    final hourly = (_weather?['hourly'] as List?) ?? const [];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: fx.background,
        body: RefreshIndicator(
          color: fx.accent,
          onRefresh: () => _load(refresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              XpressoSliverAppBar(
                title: I18n.t(context, 'weather_title'),
                showBack: true,
                onBack: _handleBack,
              ),
              if (_loading && _weather == null)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_error != null && _weather == null)
                SliverFillRemaining(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 48, color: fx.meta),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: fx.summary, height: 1.35),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => _load(refresh: true),
                          child: Text(I18n.t(context, 'action_retry')),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            fx.accent.withValues(alpha: 0.22),
                            fx.surfaceElevated,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: fx.divider.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _iconFor(current['icon']?.toString()),
                            size: 56,
                            color: fx.accent,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  location['city']?.toString() ??
                                      I18n.t(context, 'weather_your_city'),
                                  style: fx.screenTitleStyle.copyWith(fontSize: 22),
                                ),
                                if (location['state'] != null)
                                  Text(
                                    location['state'].toString(),
                                    style: TextStyle(color: fx.meta, fontSize: 13),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  current['condition']?.toString() ?? '—',
                                  style: TextStyle(
                                    color: fx.summary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${current['temperatureC'] is num ? (current['temperatureC'] as num).round() : '—'}°C',
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    color: fx.title,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  '${I18n.t(context, 'weather_feels_like')} ${current['apparentTemperatureC'] is num ? (current['apparentTemperatureC'] as num).round() : '—'}°C',
                                  style: TextStyle(color: fx.meta, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _StatChip(
                          icon: Icons.water_drop_outlined,
                          label:
                              '${current['humidityPercent'] is num ? (current['humidityPercent'] as num).round() : '—'}%',
                          caption: I18n.t(context, 'weather_humidity'),
                        ),
                        const SizedBox(width: 10),
                        _StatChip(
                          icon: Icons.air_rounded,
                          label:
                              '${current['windSpeedKmh'] is num ? (current['windSpeedKmh'] as num).round() : '—'} km/h',
                          caption: I18n.t(context, 'weather_wind'),
                        ),
                        const SizedBox(width: 10),
                        _StatChip(
                          icon: Icons.umbrella_outlined,
                          label:
                              '${current['precipitationMm'] is num ? (current['precipitationMm'] as num).toStringAsFixed(1) : '0'} mm',
                          caption: I18n.t(context, 'weather_rain'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (hourly.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        I18n.t(context, 'weather_hourly'),
                        style: fx.screenTitleStyle.copyWith(fontSize: 16),
                      ),
                    ),
                  ),
                if (hourly.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 96,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: hourly.length.clamp(0, 12),
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final row = hourly[index] is Map
                              ? Map<String, dynamic>.from(hourly[index] as Map)
                              : const <String, dynamic>{};
                          return Container(
                            width: 72,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: fx.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: fx.divider.withValues(alpha: 0.45)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _formatHour(row['time']?.toString()),
                                  style: TextStyle(fontSize: 11, color: fx.meta),
                                ),
                                const SizedBox(height: 4),
                                Icon(
                                  _iconFor(row['icon']?.toString()),
                                  size: 20,
                                  color: fx.accent,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${row['temperatureC'] is num ? (row['temperatureC'] as num).round() : '—'}°',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: fx.title,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (daily.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        I18n.t(context, 'weather_forecast'),
                        style: fx.screenTitleStyle.copyWith(fontSize: 16),
                      ),
                    ),
                  ),
                if (daily.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: daily.length.clamp(0, 7),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final row = daily[index] is Map
                            ? Map<String, dynamic>.from(daily[index] as Map)
                            : const <String, dynamic>{};
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: fx.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: fx.divider.withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 44,
                                child: Text(
                                  _formatDay(row['date']?.toString()),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: fx.title,
                                  ),
                                ),
                              ),
                              Icon(
                                _iconFor(row['icon']?.toString()),
                                color: fx.accent,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  row['condition']?.toString() ?? '—',
                                  style: TextStyle(color: fx.summary, fontSize: 13),
                                ),
                              ),
                              Text(
                                '${row['tempMinC'] is num ? (row['tempMinC'] as num).round() : '—'}° / ${row['tempMaxC'] is num ? (row['tempMaxC'] as num).round() : '—'}°',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: fx.title,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: fx.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fx.divider.withValues(alpha: 0.45)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: fx.accent),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w800, color: fx.title),
            ),
            Text(caption, style: TextStyle(fontSize: 10, color: fx.meta)),
          ],
        ),
      ),
    );
  }
}
