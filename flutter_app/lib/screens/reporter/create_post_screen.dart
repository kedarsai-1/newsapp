import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:typed_data';

import '../../providers/reporter_provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../utils/app_utils.dart';
import '../auth/widgets/auth_text_field.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import '../onboarding/onboarding_design.dart';

class CreatePostScreen extends StatefulWidget {
  final String? postId;
  const CreatePostScreen({super.key, this.postId});
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
  List<MediaItem> _existingMedia = [];
  String? _rejectionReason;
  bool _loadingPost = false;
  final Map<String, Uint8List> _previewCache = {};
  Position? _gpsPosition;
  bool _locationLoading = false;

  bool get _isEdit => widget.postId != null && widget.postId!.isNotEmpty;

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
    if (_isEdit) _loadPostForEdit();
  }

  Future<void> _loadPostForEdit() async {
    setState(() => _loadingPost = true);
    final post = await context
        .read<ReporterProvider>()
        .loadPostForEdit(widget.postId!);
    if (!mounted) return;
    if (post != null) {
      _titleCtrl.text = post.title;
      _bodyCtrl.text = post.body;
      _summaryCtrl.text = post.summary ?? '';
      _tagsCtrl.text = post.tags.join(', ');
      _selectedCategoryId = post.category?.id;
      _existingMedia = List.from(post.media);
      _rejectionReason = post.rejectionReason;
    }
    setState(() => _loadingPost = false);
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
    final accent = OnboardingDesign.accent(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: OnboardingDesign.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.photo_library, color: accent),
            title: Text('Photo from Gallery', style: _sheetTitle(context)),
            onTap: () async {
              Navigator.pop(context);
              final picked = await picker.pickMultiImage(imageQuality: 85);
              if (picked.isNotEmpty && mounted) setState(() => _mediaFiles.addAll(picked));
            },
          ),
          ListTile(
            leading: Icon(Icons.camera_alt, color: accent),
            title: Text('Take Photo', style: _sheetTitle(context)),
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
            },
          ),
          ListTile(
            leading: Icon(Icons.videocam, color: accent),
            title: Text('Video from Gallery', style: _sheetTitle(context)),
            onTap: () async {
              Navigator.pop(context);
              final picked = await picker.pickVideo(source: ImageSource.gallery);
              if (picked != null && mounted) setState(() => _mediaFiles.add(picked));
            },
          ),
          ListTile(
            leading: Icon(Icons.video_call, color: accent),
            title: Text('Record Video', style: _sheetTitle(context)),
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
            },
          ),
        ]),
      ),
    );
  }

  TextStyle _sheetTitle(BuildContext context) => GoogleFonts.notoSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: OnboardingDesign.titleColor(context),
      );

  Future<void> _submit({bool isDraft = false}) async {
    if (_isEdit && isDraft) {
      AppUtils.showError(context, 'Saving as draft is only available when creating a new story.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      AppUtils.showError(context, 'Please select a category.');
      return;
    }
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();
    final provider = context.read<ReporterProvider>();
    final bool ok;
    if (_isEdit) {
      ok = await provider.updatePost(
        postId: widget.postId!,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        summary: _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
        categoryId: _selectedCategoryId!,
        tags: tags,
        mediaFiles: _mediaFiles,
      );
    } else {
      ok = await provider.submitPost(
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
    }
    if (ok && mounted) {
      AppUtils.showSuccess(
        context,
        _isEdit
            ? 'Story re-submitted for review!'
            : (isDraft ? 'Draft saved!' : 'Story submitted for review!'),
      );
      context.go('/reporter/posts');
    } else if (provider.error != null && mounted) {
      AppUtils.showError(context, provider.error!);
    }
  }

  Future<void> _removeExistingMedia(MediaItem item) async {
    if (!_isEdit || widget.postId == null) return;
    final provider = context.read<ReporterProvider>();
    final ok = await provider.deleteMedia(
      postId: widget.postId!,
      mediaId: item.id,
    );
    if (ok && mounted) {
      setState(() => _existingMedia.removeWhere((m) => m.id == item.id));
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

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    final fx = context.fx;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(OnboardingDesign.radiusCard),
      borderSide: BorderSide(color: OnboardingDesign.outline(context)),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.notoSans(
        fontSize: 14.5,
        color: OnboardingDesign.subtitleColor(context),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: OnboardingDesign.surface(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: OnboardingDesign.accent(context), width: 1.6),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: fx.error, width: 1.4),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: fx.error, width: 1.6),
      ),
      errorStyle: GoogleFonts.notoSans(
        fontSize: 12,
        color: fx.onErrorSurface,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final loading = context.watch<ReporterProvider>().loading;
    final bottom = MediaQuery.paddingOf(context).bottom;

    if (_loadingPost) {
      return Scaffold(
        backgroundColor: OnboardingDesign.background(context),
        appBar: AppBar(
          backgroundColor: OnboardingDesign.background(context),
          elevation: 0,
        ),
        body: Center(
          child: CircularProgressIndicator(color: OnboardingDesign.accent(context)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: OnboardingDesign.background(context),
      appBar: AppBar(
        backgroundColor: OnboardingDesign.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: OnboardingDesign.titleColor(context),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          _isEdit ? 'Edit Story' : 'New Story',
          style: GoogleFonts.notoSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: OnboardingDesign.titleColor(context),
          ),
        ),
        actions: [
          if (!_isEdit)
            TextButton(
              onPressed: loading ? null : () => _submit(isDraft: true),
              child: Text(
                'Save Draft',
                style: GoogleFonts.notoSans(
                  fontWeight: FontWeight.w700,
                  color: OnboardingDesign.accent(context),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  if (_rejectionReason != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: fx.errorSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: fx.errorBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: fx.error, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _rejectionReason!,
                              style: GoogleFonts.notoSans(
                                fontSize: 13,
                                color: fx.onErrorSurface,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  if (!_isEdit)
                    _GpsBar(
                      loading: _locationLoading,
                      position: _gpsPosition,
                      onRefresh: _captureLocation,
                    ),
                  if (!_isEdit) SizedBox(height: 16),
                  const _FieldLabel('Story Headline', required: true),
                  SizedBox(height: 8),
                  AuthTextField(
                    controller: _titleCtrl,
                    hintText: 'Write a compelling headline...',
                    maxLength: 200,
                    validator: (v) => AppUtils.validateMinLength(v, 'Headline', 5),
                  ),
                  SizedBox(height: 14),
                  const _FieldLabel('Short Summary'),
                  SizedBox(height: 8),
                  AuthTextField(
                    controller: _summaryCtrl,
                    hintText: 'Brief description shown in the feed...',
                    maxLength: 300,
                  ),
                  SizedBox(height: 14),
                  const _FieldLabel('Story Body', required: true),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _bodyCtrl,
                    maxLines: 10,
                    maxLength: 10000,
                    validator: (v) => AppUtils.validateMinLength(v, 'Story body', 20),
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: OnboardingDesign.titleColor(context),
                    ),
                    cursorColor: OnboardingDesign.accent(context),
                    decoration: _inputDecoration(context, 'Write the full story here...'),
                  ),
                  SizedBox(height: 14),
                  const _FieldLabel('Category', required: true),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: _inputDecoration(context, 'Select a category'),
                    dropdownColor: OnboardingDesign.surfaceElevated(context),
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: OnboardingDesign.titleColor(context),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem<String>(
                              value: c.id,
                              child: Text('${c.icon} ${c.name}'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                    validator: (v) => v != null ? null : 'Select a category',
                  ),
                  SizedBox(height: 14),
                  const _FieldLabel('Tags'),
                  SizedBox(height: 8),
                  AuthTextField(
                    controller: _tagsCtrl,
                    hintText: 'politics, flood, vijayawada',
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Comma-separated',
                    style: GoogleFonts.notoSans(
                      fontSize: 12.5,
                      color: OnboardingDesign.subtitleColor(context),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Media',
                        style: GoogleFonts.notoSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: OnboardingDesign.titleColor(context),
                        ),
                      ),
                      TextButton.icon(
                        icon: Icon(Icons.add_photo_alternate_outlined,
                            color: OnboardingDesign.accent(context), size: 20),
                        label: Text(
                          'Add',
                          style: GoogleFonts.notoSans(
                            fontWeight: FontWeight.w700,
                            color: OnboardingDesign.accent(context),
                          ),
                        ),
                        onPressed: _pickMedia,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (_existingMedia.isNotEmpty) ...[
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _existingMedia.length,
                        separatorBuilder: (_, __) => SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final item = _existingMedia[i];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: item.isVideo
                                    ? Container(
                                        width: 100,
                                        height: 100,
                                        color: fx.surface,
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.videocam_outlined,
                                          size: 36,
                                          color: OnboardingDesign.subtitleColor(context),
                                        ),
                                      )
                                    : Image.network(
                                        item.url,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 100,
                                          height: 100,
                                          color: fx.surface,
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: OnboardingDesign.subtitleColor(context),
                                          ),
                                        ),
                                      ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeExistingMedia(item),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: fx.overlayScrim,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: fx.onImage,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 12),
                  ],
                  if (_mediaFiles.isEmpty && _existingMedia.isEmpty)
                    GestureDetector(
                      onTap: _pickMedia,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: OnboardingDesign.surface(context),
                          border: Border.all(color: OnboardingDesign.outline(context)),
                          borderRadius: BorderRadius.circular(OnboardingDesign.radiusCard),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 32, color: OnboardingDesign.subtitleColor(context)),
                            SizedBox(height: 6),
                            Text(
                              'Tap to add photos or videos',
                              style: GoogleFonts.notoSans(
                                color: OnboardingDesign.subtitleColor(context),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _mediaFiles.length + 1,
                        separatorBuilder: (_, __) => SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          if (i == _mediaFiles.length) {
                            return GestureDetector(
                              onTap: _pickMedia,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  border: Border.all(color: OnboardingDesign.outline(context)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.add, color: OnboardingDesign.subtitleColor(context)),
                              ),
                            );
                          }
                          return Stack(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _isVideo(_mediaFiles[i])
                                  ? Container(
                                      width: 100,
                                      height: 100,
                                      color: fx.surface,
                                      alignment: Alignment.center,
                                      child: Icon(Icons.videocam_outlined,
                                          size: 36, color: OnboardingDesign.subtitleColor(context)),
                                    )
                                  : FutureBuilder<Uint8List>(
                                      future: _getPreviewBytes(_mediaFiles[i]),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return Container(
                                            width: 100,
                                            height: 100,
                                            color: fx.surface,
                                            alignment: Alignment.center,
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: OnboardingDesign.accent(context),
                                              ),
                                            ),
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
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _mediaFiles.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: fx.overlayScrim,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close, color: fx.onImage, size: 14),
                                ),
                              ),
                            ),
                          ]);
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  onPressed: loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: OnboardingDesign.accent(context),
                    disabledBackgroundColor:
                        OnboardingDesign.accent(context).withValues(alpha: 0.55),
                    foregroundColor: context.fx.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OnboardingDesign.radiusButton),
                    ),
                    elevation: 0,
                  ),
                  child: loading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: context.fx.onAccent, strokeWidth: 2.4),
                        )
                      : Text(
                          _isEdit ? 'Re-submit for Approval' : 'Submit for Approval',
                          style: OnboardingDesign.buttonLabel(context),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: GoogleFonts.notoSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: OnboardingDesign.titleColor(context),
          ),
        ),
        if (required) ...[
          SizedBox(width: 3),
          Text(
            '*',
            style: GoogleFonts.notoSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: OnboardingDesign.accent(context),
            ),
          ),
        ],
      ],
    );
  }
}

class _GpsBar extends StatelessWidget {
  final bool loading;
  final Position? position;
  final VoidCallback onRefresh;

  const _GpsBar({
    required this.loading,
    required this.position,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final hasGps = position != null;
    final bg = hasGps
        ? OnboardingDesign.accent(context).withValues(alpha: 0.08)
        : fx.warningSurface;
    final iconColor = hasGps
        ? OnboardingDesign.accent(context)
        : fx.onWarningSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasGps
              ? OnboardingDesign.accent(context).withValues(alpha: 0.25)
              : fx.warningBorder,
        ),
      ),
      child: Row(children: [
        Icon(
          loading
              ? Icons.gps_not_fixed
              : (hasGps ? Icons.gps_fixed : Icons.location_off),
          size: 18,
          color: iconColor,
        ),
        SizedBox(width: 8),
        Expanded(
          child: loading
              ? Text(
                  'Capturing GPS...',
                  style: GoogleFonts.notoSans(
                    fontSize: 13,
                    color: OnboardingDesign.subtitleColor(context),
                  ),
                )
              : hasGps
                  ? Text(
                      '📍 ${position!.latitude.toStringAsFixed(4)}, ${position!.longitude.toStringAsFixed(4)}',
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OnboardingDesign.titleColor(context),
                      ),
                    )
                  : Text(
                      'Location unavailable',
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        color: fx.onWarningSurface,
                      ),
                    ),
        ),
        if (!loading)
          IconButton(
            icon: Icon(Icons.refresh, size: 18, color: OnboardingDesign.subtitleColor(context)),
            onPressed: onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ]),
    );
  }
}
