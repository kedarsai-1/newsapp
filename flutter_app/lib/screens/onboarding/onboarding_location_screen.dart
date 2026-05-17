import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/onboarding_draft_provider.dart';
import 'onboarding_design.dart';
import 'widgets/onboarding_shell.dart';

class OnboardingLocationScreen extends StatefulWidget {
  const OnboardingLocationScreen({super.key});

  @override
  State<OnboardingLocationScreen> createState() =>
      _OnboardingLocationScreenState();
}

class _OnboardingLocationScreenState extends State<OnboardingLocationScreen> {
  final TextEditingController _search = TextEditingController();
  bool _locLoading = false;
  String? _geoError;

  static const _popular = <String>[
    'Hyderabad',
    'Bengaluru',
    'Chennai',
    'Mumbai',
    'Delhi',
    'Kolkata',
    'Pune',
    'Ahmedabad',
    'Kochi',
    'Visakhapatnam',
    'Vijayawada',
    'Mysuru',
    'Thiruvananthapuram',
    'Guwahati',
    'Jaipur',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locLoading = true;
      _geoError = null;
    });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled && mounted) {
        setState(() {
          _geoError = 'Turn on location services to use this option.';
          _locLoading = false;
        });
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _geoError = 'Location permission denied.';
            _locLoading = false;
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final name = marks.isNotEmpty
          ? (marks.first.locality?.trim().isNotEmpty == true
                  ? marks.first.locality
                  : marks.first.subAdministrativeArea)
              ?.trim()
          : null;
      if (!mounted) return;
      if (name != null && name.isNotEmpty) {
        context.read<OnboardingDraftProvider>().setCity(name);
      } else {
        setState(() => _geoError = 'Could not resolve city name.');
      }
    } catch (_) {
      if (mounted) setState(() => _geoError = 'Could not read location.');
    } finally {
      if (mounted) setState(() => _locLoading = false);
    }
  }

  List<String> _filtered() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _popular;
    return _popular.where((c) => c.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<OnboardingDraftProvider>();

    return OnboardingStepShell(
      title: 'Choose your location',
      subtitle: 'Get local and regional news',
      primaryLabel: 'Continue',
      onPrimary: () => context.go('/onboarding/notifications'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search city',
              hintStyle: OnboardingDesign.languageEn(context),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: OnboardingDesign.subtitleColor(context).withValues(alpha: 0.85),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(OnboardingDesign.radiusCard),
                borderSide: BorderSide(color: OnboardingDesign.outline(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(OnboardingDesign.radiusCard),
                borderSide: BorderSide(color: OnboardingDesign.outline(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(OnboardingDesign.radiusCard),
                borderSide: BorderSide(
                    color: OnboardingDesign.accent(context), width: 1.4),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _locLoading ? null : _useCurrentLocation,
              borderRadius: BorderRadius.circular(OnboardingDesign.radiusCard),
              child: Ink(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(OnboardingDesign.radiusCard),
                  border: Border.all(color: OnboardingDesign.outline(context)),
                  color: const Color(0xFFF9FAFB),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.my_location_rounded,
                      color: OnboardingDesign.accent(context),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _locLoading
                            ? 'Getting location…'
                            : 'Use current location',
                        style: OnboardingDesign.languageNative(context)
                            .copyWith(fontSize: 15),
                      ),
                    ),
                    if (_locLoading)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: OnboardingDesign.accent(context).withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_geoError != null) ...[
            const SizedBox(height: 8),
            Text(
              _geoError!,
              style: OnboardingDesign.languageEn(context)
                  .copyWith(color: Colors.red.shade700),
            ),
          ],
          const SizedBox(height: 8),
          if (draft.cityLabel.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Selected: ${draft.cityLabel}',
                style: OnboardingDesign.languageEn(context).copyWith(
                  color: OnboardingDesign.accentDark(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(
            'Popular cities',
            style: OnboardingDesign.languageNative(context).copyWith(fontSize: 14),
          ),
          const SizedBox(height: 8),
          ..._filtered().map((city) {
            final picked = draft.cityLabel == city;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      context.read<OnboardingDraftProvider>().setCity(city),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: picked
                            ? OnboardingDesign.accent(context)
                            : OnboardingDesign.outline(context),
                      ),
                      color: picked
                          ? OnboardingDesign.accent(context).withValues(alpha: 0.06)
                          : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_city_outlined,
                          size: 20,
                          color: picked
                              ? OnboardingDesign.accent(context)
                              : OnboardingDesign.subtitleColor(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            city,
                            style: OnboardingDesign.languageNative(context).copyWith(
                              fontSize: 15,
                              color: OnboardingDesign.titleColor(context),
                            ),
                          ),
                        ),
                        if (picked)
                          Icon(Icons.check_circle_rounded,
                              color: OnboardingDesign.accent(context), size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
