import 'package:flutter/material.dart';

import '../../models/saved_local_place.dart';
import '../../services/api_service.dart';
import 'feed_xpresso_theme.dart';

class LocalLocationPickerSheet extends StatefulWidget {
  const LocalLocationPickerSheet({
    super.key,
    required this.slot,
    this.initial,
    this.defaultLabel = 'Home',
  });

  final int slot;
  final SavedLocalPlace? initial;
  final String defaultLabel;

  @override
  State<LocalLocationPickerSheet> createState() => _LocalLocationPickerSheetState();
}

class _LocalLocationPickerSheetState extends State<LocalLocationPickerSheet> {
  final _search = TextEditingController();
  final _label = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _label.text = widget.initial?.label ?? widget.defaultLabel;
    if (widget.initial != null && !widget.initial!.isEmpty) {
      _selected = {
        'name': widget.initial!.mandal ?? widget.initial!.city ?? widget.initial!.district,
        'district': widget.initial!.district,
        'state': widget.initial!.state,
      };
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.searchGeoMandals(query: q, limit: 40);
      final list = res['mandals'] is List ? res['mandals'] as List : const [];
      setState(() {
        _results = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    final label = _label.text.trim().isEmpty ? widget.defaultLabel : _label.text.trim();
    if (_selected != null) {
      final name = _selected!['name']?.toString();
      Navigator.of(context).pop(
        SavedLocalPlace(
          label: label,
          mandal: name,
          district: _selected!['district']?.toString(),
          state: _selected!['state']?.toString(),
          city: name,
        ),
      );
      return;
    }

    final city = _search.text.trim();
    if (city.isEmpty) {
      setState(() => _error = 'Search a mandal or enter a city name.');
      return;
    }

    try {
      final geo = await ApiService.forwardGeocode(city: city);
      if (geo['success'] == true && geo['location'] is Map) {
        final loc = Map<String, dynamic>.from(geo['location'] as Map);
        Navigator.of(context).pop(
          SavedLocalPlace(
            label: label,
            city: loc['city']?.toString() ?? city,
            state: loc['state']?.toString(),
            latitude: (loc['latitude'] as num?)?.toDouble(),
            longitude: (loc['longitude'] as num?)?.toDouble(),
          ),
        );
        return;
      }
    } catch (_) {}

    Navigator.of(context).pop(
      SavedLocalPlace(label: label, city: city),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      margin: const EdgeInsets.only(top: 48),
      decoration: BoxDecoration(
        color: fx.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: fx.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.slot == 0 ? 'Home location' : 'Native / 2nd place',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: fx.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _label,
            decoration: InputDecoration(
              labelText: 'Label',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Search mandal, city or district',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _runSearch(_search.text.trim()),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: _runSearch,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: fx.error, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final row = _results[index];
                final name = row['name']?.toString() ?? '';
                final district = row['district']?.toString() ?? '';
                final state = row['state']?.toString() ?? '';
                final selected = _selected?['name'] == name &&
                    _selected?['district'] == district;
                return ListTile(
                  dense: true,
                  selected: selected,
                  title: Text(name),
                  subtitle: Text('$district · $state'),
                  onTap: () => setState(() => _selected = row),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (widget.initial != null && !widget.initial!.isEmpty)
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(const SavedLocalPlace()),
              child: const Text('Clear location'),
            ),
          if (widget.initial != null && !widget.initial!.isEmpty)
            const SizedBox(height: 8),
          FilledButton(
            onPressed: _save,
            child: const Text('Save location'),
          ),
        ],
      ),
    );
  }
}
