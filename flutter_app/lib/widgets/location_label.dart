import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import '../models/models.dart';
import '../theme/app_palette.dart';

/// Shows city/state or address from [location], or resolves a place name from
/// coordinates when the API only stored lat/lng (e.g. server geocode failed).
class LocationLabel extends StatefulWidget {
  final LocationData location;
  final TextStyle? style;
  final IconData icon;
  final double iconSize;
  final bool showIcon;
  /// Use [Expanded] around the text (wide layouts). Set false inside [Wrap] meta rows.
  final bool expandText;
  final double? maxTextWidth;
  final Color? iconColor;

  const LocationLabel({
    super.key,
    required this.location,
    this.style,
    this.icon = Icons.location_on_outlined,
    this.iconSize = 14,
    this.showIcon = true,
    this.expandText = true,
    this.maxTextWidth,
    this.iconColor,
  });

  @override
  State<LocationLabel> createState() => _LocationLabelState();
}

class _LocationLabelState extends State<LocationLabel> {
  String? _label;

  @override
  void initState() {
    super.initState();
    _label = _immediateLabel(widget.location);
    if (_needsClientGeocode(widget.location)) {
      _resolve();
    }
  }

  @override
  void didUpdateWidget(LocationLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.latitude != widget.location.latitude ||
        oldWidget.location.longitude != widget.location.longitude) {
      _label = _immediateLabel(widget.location);
      if (_needsClientGeocode(widget.location)) {
        _resolve();
      } else {
        setState(() {});
      }
    }
  }

  bool _needsClientGeocode(LocationData loc) {
    if (loc.city != null && loc.city!.trim().isNotEmpty) return false;
    if (loc.state != null && loc.state!.trim().isNotEmpty) return false;
    if (loc.address != null && loc.address!.trim().isNotEmpty) return false;
    return true;
  }

  String _immediateLabel(LocationData loc) => loc.displayLocation;

  Future<void> _resolve() async {
    if (kIsWeb) {
      setState(() => _label = widget.location.displayLocation);
      return;
    }
    final loc = widget.location;
    try {
      final places = await placemarkFromCoordinates(loc.latitude, loc.longitude);
      if (!mounted) return;
      if (places.isEmpty) {
        setState(() => _label = loc.displayLocation);
        return;
      }
      final line = _placemarkLine(places.first);
      setState(() => _label = line ?? loc.displayLocation);
    } catch (_) {
      if (mounted) setState(() => _label = loc.displayLocation);
    }
  }

  String? _placemarkLine(Placemark p) {
    final locality = p.locality ?? p.subLocality ?? p.name;
    final region = p.administrativeArea ?? p.subAdministrativeArea;
    final parts = <String>[];
    if (locality != null && locality.trim().isNotEmpty) parts.add(locality.trim());
    if (region != null && region.trim().isNotEmpty && region != locality) {
      parts.add(region.trim());
    }
    if (parts.isNotEmpty) return parts.join(', ');
    if (p.street != null && p.street!.trim().isNotEmpty) return p.street!.trim();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? TextStyle(fontSize: 12, color: context.palette.textHint);
    final text = _label ?? widget.location.displayLocation;
    final effectiveIconColor = widget.iconColor ?? style.color;
    if (!widget.showIcon) {
      return Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    final textWidget = Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    if (!widget.expandText) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(widget.icon, size: widget.iconSize, color: effectiveIconColor),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxTextWidth ?? 200),
            child: textWidget,
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(widget.icon, size: widget.iconSize, color: effectiveIconColor),
        const SizedBox(width: 4),
        Expanded(child: textWidget),
      ],
    );
  }
}
