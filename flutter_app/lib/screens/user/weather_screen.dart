import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import '../../utils/i18n.dart';
import '../../widgets/dailyhunt/xpresso_sliver_app_bar.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Live weather for the user's city (Open-Meteo via backend) - Modern glass design.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  Map<String, dynamic>? _weather;
  String? _error;
  bool _loading = true;
  bool _loadingFromCache = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool refresh = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = _weather == null;
      _loadingFromCache = false;
      if (refresh) _error = null;
    });

    final news = context.read<NewsProvider>();
    final city = news.preferredCity?.trim().isNotEmpty == true
        ? news.preferredCity!.trim()
        : 'Hyderabad';
    final state = news.activeSavedLocation?.state?.trim();

    // First try to load cached data for initial load
    if (!refresh && _weather == null) {
      try {
        final cachedRes = await ApiService.getWeather(
          city: city,
          state: state?.isNotEmpty == true ? state : null,
          memoryCacheTtl: const Duration(hours: 1), // Try to get cached data
        );
        if (cachedRes['success'] == true && mounted) {
          setState(() {
            _weather = Map<String, dynamic>.from(cachedRes);
            _loading = false;
            _loadingFromCache = true;
          });
        }
      } catch (e) {
        // No cached data, continue with fresh request
        if (mounted) setState(() => _loadingFromCache = false);
      }
    }

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
        _loadingFromCache = false;
      });
    } else {
      // Keep cached data available on network failure
      setState(() {
        _error = res['message']?.toString() ?? I18n.t(context, 'weather_unavailable');
        _loading = false;
        _loadingFromCache = false;
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
                  child: _ErrorState(
                    error: _error!,
                    onRetry: () => _load(refresh: true),
                  ),
                )
              else ...[
                if (_loadingFromCache || (_error != null && _weather != null))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: _StatusBanner(
                        loadingFromCache: _loadingFromCache,
                        error: _error,
                        onRetry: () => _load(refresh: true),
                        fx: fx,
                      ),
                    ),
                  ),
                // ── Hero Weather Card ──────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _HeroWeatherCard(
                      current: current,
                      location: location,
                      iconFor: _iconFor,
                      fx: fx,
                    ),
                  ),
                ),

                // ── Stats Row ────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _GlassStatChip(
                          icon: Icons.water_drop_outlined,
                          label:
                              '${current['humidityPercent'] is num ? (current['humidityPercent'] as num).round() : '—'}%',
                          caption: I18n.t(context, 'weather_humidity'),
                          fx: fx,
                        ),
                        const SizedBox(width: 10),
                        _GlassStatChip(
                          icon: Icons.air_rounded,
                          label:
                              '${current['windSpeedKmh'] is num ? (current['windSpeedKmh'] as num).round() : '—'} km/h',
                          caption: I18n.t(context, 'weather_wind'),
                          fx: fx,
                        ),
                        const SizedBox(width: 10),
                        _GlassStatChip(
                          icon: Icons.umbrella_outlined,
                          label:
                              '${current['precipitationMm'] is num ? (current['precipitationMm'] as num).toStringAsFixed(1) : '0'} mm',
                          caption: I18n.t(context, 'weather_rain'),
                          fx: fx,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Hourly Forecast ───────────────────────────────
                if (hourly.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 18, color: fx.accent),
                          const SizedBox(width: 8),
                          Text(
                            I18n.t(context, 'weather_hourly'),
                            style: GoogleFonts.notoSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: fx.title,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 110,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: hourly.length.clamp(0, 12),
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final row = hourly[index] is Map
                              ? Map<String, dynamic>.from(hourly[index] as Map)
                              : const <String, dynamic>{};
                          return _HourlyCard(
                            hour: _formatHour(row['time']?.toString()),
                            icon: _iconFor(row['icon']?.toString()),
                            temp: '${row['temperatureC'] is num ? (row['temperatureC'] as num).round() : '—'}°',
                            fx: fx,
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // ── Daily Forecast ────────────────────────────────
                if (daily.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 18, color: fx.accent),
                          const SizedBox(width: 8),
                          Text(
                            I18n.t(context, 'weather_forecast'),
                            style: GoogleFonts.notoSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: fx.title,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: daily.length.clamp(0, 7),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final row = daily[index] is Map
                            ? Map<String, dynamic>.from(daily[index] as Map)
                            : const <String, dynamic>{};
                        return _DailyForecastCard(
                          day: _formatDay(row['date']?.toString()),
                          icon: _iconFor(row['icon']?.toString()),
                          condition: row['condition']?.toString() ?? '—',
                          tempRange:
                              '${row['tempMinC'] is num ? (row['tempMinC'] as num).round() : '—'}° / ${row['tempMaxC'] is num ? (row['tempMaxC'] as num).round() : '—'}°',
                          fx: fx,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool loadingFromCache;
  final String? error;
  final VoidCallback onRetry;
  final dynamic fx;

  const _StatusBanner({
    required this.loadingFromCache,
    required this.error,
    required this.onRetry,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null && error!.trim().isNotEmpty;
    final bannerColor = hasError
        ? fx.error.withValues(alpha: 0.12)
        : fx.accent.withValues(alpha: 0.12);
    final borderColor = hasError
        ? fx.error.withValues(alpha: 0.35)
        : fx.accent.withValues(alpha: 0.3);
    final iconColor = hasError ? fx.error : fx.accent;
    final message = loadingFromCache
        ? 'Showing cached weather while reconnecting...'
        : (error ?? 'Connection restored');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            hasError ? Icons.cloud_off_rounded : Icons.cloud_sync_rounded,
            size: 18,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.notoSans(
                fontSize: 12,
                color: fx.title,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: iconColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: fx.errorSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_off_rounded, size: 48, color: fx.error),
          ),
          const SizedBox(height: 20),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(
              color: fx.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _GradientButton(
            label: I18n.t(context, 'action_retry'),
            icon: Icons.refresh_rounded,
            onTap: onRetry,
            fx: fx,
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final dynamic fx;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.fx,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [widget.fx.accent, widget.fx.accentTertiary],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.fx.accent.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.notoSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroWeatherCard extends StatelessWidget {
  final Map<String, dynamic> current;
  final Map<String, dynamic> location;
  final IconData Function(String?) iconFor;
  final dynamic fx;

  const _HeroWeatherCard({
    required this.current,
    required this.location,
    required this.iconFor,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fx.accent.withValues(alpha: 0.2),
            fx.accentTertiary.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: fx.glassBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: fx.accent.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Weather icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: fx.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: fx.accent.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              iconFor(current['icon']?.toString()),
              size: 44,
              color: fx.accent,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 16, color: fx.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location['city']?.toString() ?? 'Your Location',
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: fx.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (location['state'] != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text(
                      location['state'].toString(),
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        color: fx.textHint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  current['condition']?.toString() ?? '—',
                  style: GoogleFonts.notoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fx.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${current['temperatureC'] is num ? (current['temperatureC'] as num).round() : '—'}',
                      style: GoogleFonts.notoSans(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: fx.title,
                        height: 1,
                        letterSpacing: -2,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '°C',
                        style: GoogleFonts.notoSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: fx.title,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Feels ${current['apparentTemperatureC'] is num ? (current['apparentTemperatureC'] as num).round() : '—'}°',
                  style: GoogleFonts.notoSans(
                    fontSize: 12,
                    color: fx.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;
  final dynamic fx;

  const _GlassStatChip({
    required this.icon,
    required this.label,
    required this.caption,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: fx.glassSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: fx.glassBorder),
          boxShadow: [
            BoxShadow(
              color: fx.heroShadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fx.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: fx.accent),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.notoSans(
                fontWeight: FontWeight.w800,
                color: fx.title,
                fontSize: 13,
              ),
            ),
            Text(
              caption,
              style: GoogleFonts.notoSans(
                fontSize: 10,
                color: fx.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourlyCard extends StatelessWidget {
  final String hour;
  final IconData icon;
  final String temp;
  final dynamic fx;

  const _HourlyCard({
    required this.hour,
    required this.icon,
    required this.temp,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: fx.glassSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: fx.glassBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hour,
            style: GoogleFonts.notoSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fx.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Icon(icon, size: 26, color: fx.accent),
          const SizedBox(height: 8),
          Text(
            temp,
            style: GoogleFonts.notoSans(
              fontWeight: FontWeight.w800,
              color: fx.title,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyForecastCard extends StatelessWidget {
  final String day;
  final IconData icon;
  final String condition;
  final String tempRange;
  final dynamic fx;

  const _DailyForecastCard({
    required this.day,
    required this.icon,
    required this.condition,
    required this.tempRange,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fx.glassSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fx.glassBorder),
        boxShadow: [
          BoxShadow(
            color: fx.heroShadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              day,
              style: GoogleFonts.notoSans(
                fontWeight: FontWeight.w800,
                color: fx.title,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: fx.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: fx.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              condition,
              style: GoogleFonts.notoSans(
                color: fx.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            tempRange,
            style: GoogleFonts.notoSans(
              fontWeight: FontWeight.w800,
              color: fx.title,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
