import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../providers/reporter_provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../utils/app_utils.dart';
import '../../constants.dart';
import '../../theme/app_palette.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:typed_data';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  List<Category> _categories = [];
  String? _selectedCategoryId;
  List<XFile> _mediaFiles = [];
  final Map<String, Uint8List> _previewCache = {};
  Position? _gpsPosition;
  bool _locationLoading = false;

  bool _isVideo(XFile file) {
    final name = file.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : '';
    return ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
  }

  Future<Uint8List> _getPreviewBytes(XFile file) async {
    final key = file.name;
    final cached = _previewCache[key];
    if (cached != null) return cached;
    final bytes = await file.readAsBytes();
    _previewCache[key] = bytes;
    return bytes;
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _captureLocation();
  }

  Future<void> _loadCategories() async {
    final cats = await ApiService.getCategories();
    if (mounted) setState(() => _categories = cats);
  }

  Future<void> _captureLocation() async {
    setState(() => _locationLoading = true);
    final pos = await LocationService.getCurrentPosition();
    if (mounted) setState(() { _gpsPosition = pos; _locationLoading = false; });
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: Icon(Icons.photo_library, color: p.primary), title: const Text('Photo from Gallery'),
            onTap: () async {
              Navigator.pop(context);
              final picked = await picker.pickMultiImage(imageQuality: 85);
              if (picked.isNotEmpty && mounted) setState(() => _mediaFiles.addAll(picked));
            }),
          ListTile(leading: Icon(Icons.camera_alt, color: p.primary), title: const Text('Take Photo'),
            onTap: () async {
              Navigator.pop(context);
              try {
                final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                if (picked != null && mounted) setState(() => _mediaFiles.add(picked));
              } catch (e) {
                if (mounted) {
                  AppUtils.showError(context, 'Camera is not available on this device/browser. Please use Gallery instead.');
                }
              }
            }),
          ListTile(leading: Icon(Icons.videocam, color: p.primary), title: const Text('Video from Gallery'),
            onTap: () async {
              Navigator.pop(context);
              final picked = await picker.pickVideo(source: ImageSource.gallery);
              if (picked != null && mounted) setState(() => _mediaFiles.add(picked));
            }),
          ListTile(leading: Icon(Icons.video_call, color: p.primary), title: const Text('Record Video'),
            onTap: () async {
              Navigator.pop(context);
              try {
                final picked = await picker.pickVideo(source: ImageSource.camera);
                if (picked != null && mounted) setState(() => _mediaFiles.add(picked));
              } catch (e) {
                if (mounted) {
                  AppUtils.showError(context, 'Video recording is not available on this device/browser. Please use Gallery instead.');
                }
              }
            }),
        ]),
      ),
    );
  }

  Future<void> _submit({bool isDraft = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      AppUtils.showError(context, 'Please select a category.');
      return;
    }
    final tags = _tagsCtrl.text.split(',').map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toList();
    final provider = context.read<ReporterProvider>();
    final ok = await provider.submitPost(
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      summary: _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
      categoryId: _selectedCategoryId!,
      latitude: _gpsPosition?.latitude,
      longitude: _gpsPosition?.longitude,
      tags: tags,
      mediaFiles: _mediaFiles,
      isDraft: isDraft,
    );
    if (ok && mounted) {
      AppUtils.showSuccess(context, isDraft ? 'Draft saved!' : 'Story submitted for review!');
      context.go('/reporter');
    } else if (provider.error != null && mounted) {
      AppUtils.showError(context, provider.error!);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _bodyCtrl.dispose();
    _summaryCtrl.dispose(); _tagsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final loading = context.watch<ReporterProvider>().loading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Story'),
        actions: [TextButton(onPressed: loading ? null : () => _submit(isDraft: true), child: const Text('Save Draft'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // GPS bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _gpsPosition != null ? p.categoryChipBg : const Color(0xFFFAEEDA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(
                _locationLoading ? Icons.gps_not_fixed : (_gpsPosition != null ? Icons.gps_fixed : Icons.location_off),
                size: 18, color: _gpsPosition != null ? p.primaryDark : p.warning,
              ),
              const SizedBox(width: 8),
              Expanded(child: _locationLoading
                  ? Text('Capturing GPS...', style: TextStyle(fontSize: 13, color: p.textSecondary))
                  : _gpsPosition != null
                      ? Text('📍 ${_gpsPosition!.latitude.toStringAsFixed(4)}, ${_gpsPosition!.longitude.toStringAsFixed(4)}',
                          style: TextStyle(fontSize: 13, color: p.primaryDark))
                      : Text('Location unavailable', style: TextStyle(fontSize: 13, color: p.warning))),
              if (!_locationLoading)
                IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _captureLocation,
                    color: p.textSecondary, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
          ),
          const SizedBox(height: 16),

          TextFormField(controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Story Headline *', hintText: 'Write a compelling headline...'),
            maxLength: 200,
            validator: (v) => AppUtils.validateMinLength(v, 'Headline', 5)),
          const SizedBox(height: 12),

          TextFormField(controller: _summaryCtrl,
            decoration: const InputDecoration(labelText: 'Short Summary (optional)', hintText: 'Brief description shown in the feed...'),
            maxLength: 300, maxLines: 2),
          const SizedBox(height: 12),

          TextFormField(controller: _bodyCtrl,
            decoration: const InputDecoration(labelText: 'Story Body *', hintText: 'Write the full story here...', alignLabelWithHint: true),
            maxLines: 10, maxLength: 10000,
            validator: (v) => AppUtils.validateMinLength(v, 'Story body', 20)),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _selectedCategoryId,
            decoration: const InputDecoration(labelText: 'Category *'),
            items: _categories
                .map(
                  (c) => DropdownMenuItem<String>(
                    value: c.id,
                    child: Text('${c.icon} ${c.name}'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedCategoryId = v),
            validator: (v) => v != null ? null : 'Select a category',
          ),
          const SizedBox(height: 12),

          TextFormField(controller: _tagsCtrl,
            decoration: const InputDecoration(labelText: 'Tags (optional)', hintText: 'politics, flood, vijayawada', helperText: 'Comma-separated')),
          const SizedBox(height: 20),

          // Media picker
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Media', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            TextButton.icon(icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Add'), onPressed: _pickMedia),
          ]),

          if (_mediaFiles.isEmpty)
            GestureDetector(
              onTap: _pickMedia,
              child: Container(
                height: 100,
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDDDDD)), borderRadius: BorderRadius.circular(10)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 32, color: p.textHint),
                  const SizedBox(height: 6),
                  Text('Tap to add photos or videos', style: TextStyle(color: p.textHint, fontSize: 13)),
                ]),
              ),
            )
          else
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _mediaFiles.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == _mediaFiles.length) {
                    return GestureDetector(onTap: _pickMedia, child: Container(width: 100, height: 100, decoration: BoxDecoration(border: Border.all(color: p.cardBorder), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.add, color: p.textHint)));
                  }
                  return Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _isVideo(_mediaFiles[i])
                          ? Container(
                              width: 100,
                              height: 100,
                              color: p.glassSurface,
                              alignment: Alignment.center,
                              child: Icon(Icons.videocam_outlined, size: 36, color: p.textHint),
                            )
                          : FutureBuilder<Uint8List>(
                              future: _getPreviewBytes(_mediaFiles[i]),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return Container(
                                    width: 100,
                                    height: 100,
                                    color: const Color(0xFFF0F0F0),
                                    alignment: Alignment.center,
                                    child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }
                                return Image.memory(
                                  snapshot.data!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                    ),
                    Positioned(top: 4, right: 4, child: GestureDetector(
                      onTap: () => setState(() => _mediaFiles.removeAt(i)),
                      child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14)),
                    )),
                  ]);
                },
              ),
            ),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: loading ? null : _submit,
            child: loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit for Approval'),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}