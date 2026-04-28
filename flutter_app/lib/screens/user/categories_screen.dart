import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../constants.dart';
import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_news_ui.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String? _selectedCategoryId;
  String _selectedCity = 'all';
  String _selectedConstituency = 'all';

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/feed');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedCategoryId ??= context.read<NewsProvider>().selectedCategoryId;
  }

  List<NewsPost> _filterPosts(List<NewsPost> posts, List<Category> categories) {
    String? selectedSlug;
    if (_selectedCategoryId != null) {
      for (final c in categories) {
        if (c.id == _selectedCategoryId) {
          selectedSlug = c.slug.toLowerCase();
          break;
        }
      }
    }

    return posts.where((post) {
      if (_selectedCategoryId != null &&
          post.category?.id != _selectedCategoryId &&
          post.category?.slug.toLowerCase() != selectedSlug) {
        return false;
      }
      final city = post.location?.city?.trim().toLowerCase() ?? '';
      final constituency = post.constituency?.trim().toLowerCase() ?? '';
      if (_selectedCity != 'all' && city != _selectedCity.toLowerCase()) {
        return false;
      }
      if (_selectedConstituency != 'all' &&
          constituency != _selectedConstituency.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final p = context.palette;
    final categories = provider.categories;
    final posts = _filterPosts(provider.posts, categories);
    final cities = <String>{
      for (final post in provider.posts)
        if ((post.location?.city ?? '').trim().isNotEmpty)
          post.location!.city!.trim(),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final constituencies = <String>{
      for (final post in provider.posts)
        if ((post.constituency ?? '').trim().isNotEmpty &&
            (post.constituency ?? '').trim().toLowerCase() != 'unknown')
          post.constituency!.trim(),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return PremiumScaffold(
      safeArea: true,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  PremiumIconButton(
                    icon: AppIcons.back,
                    onTap: _handleBack,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Categories',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.7,
                              ),
                        ),
                        Text(
                          'Choose topic and location for local briefings',
                          style: context.subtitleText.copyWith(
                            color: p.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PremiumIconButton(
                    icon: AppIcons.home,
                    onTap: () => context.go('/feed'),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            sliver: SliverToBoxAdapter(
              child: FrostedPanel(
                radius: 20,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categories',
                      style: context.metaText.copyWith(
                        color: p.textHint,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CategoryChip(
                          label: '✨ All',
                          selected: _selectedCategoryId == null,
                          onTap: () {
                            setState(() => _selectedCategoryId = null);
                            provider.selectCategory(null);
                          },
                        ),
                        ...categories.map((cat) => _CategoryChip(
                              label: '${cat.icon} ${cat.name}',
                              selected: _selectedCategoryId == cat.id,
                              onTap: () {
                                setState(() => _selectedCategoryId = cat.id);
                                provider.selectCategory(cat.id);
                              },
                            )),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _LocationDropdown(
                            label: 'City',
                            value: _selectedCity,
                            values: cities,
                            onChanged: (value) =>
                                setState(() => _selectedCity = value),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _LocationDropdown(
                            label: 'District/Constituency',
                            value: _selectedConstituency,
                            values: constituencies,
                            onChanged: (value) =>
                                setState(() => _selectedConstituency = value),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              18,
              0,
              18,
              110 + MediaQuery.of(context).padding.bottom,
            ),
            sliver: SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: posts.isEmpty
                    ? const SizedBox(
                        key: ValueKey('empty'),
                        height: 240,
                        child: EmptyState(
                          icon: AppIcons.empty,
                          title: 'No local stories found',
                          subtitle: 'Try another category or location filter.',
                        ),
                      )
                    : GridView.builder(
                        key: ValueKey(
                            'grid-${_selectedCategoryId ?? 'all'}-$_selectedCity-$_selectedConstituency'),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: posts.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.74,
                        ),
                        itemBuilder: (context, index) => _LocalNewsCard(
                          post: posts[index],
                          onTap: () =>
                              context.push('/article/${posts[index].id}'),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: p.primary.withValues(alpha: 0.22),
      backgroundColor: p.surface.withValues(alpha: 0.46),
      side: BorderSide(color: selected ? p.primary : p.cardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(
        color: selected ? p.primary : p.textSecondary,
        fontWeight: FontWeight.w800,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _LocationDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DropdownButtonFormField<String>(
      initialValue: value,
      icon: Icon(AppIcons.chevronDown, color: p.textSecondary),
      dropdownColor: p.surface,
      borderRadius: BorderRadius.circular(14),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: p.surface.withValues(alpha: 0.54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.cardBorder),
        ),
      ),
      items: [
        const DropdownMenuItem(value: 'all', child: Text('All')),
        ...values
            .map((city) => DropdownMenuItem(value: city, child: Text(city))),
      ],
      onChanged: (v) => onChanged(v ?? 'all'),
    );
  }
}

class _LocalNewsCard extends StatelessWidget {
  final NewsPost post;
  final VoidCallback onTap;

  const _LocalNewsCard({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final imageUrl = premiumImageUrl(post);
    return FrostedPanel(
      radius: 20,
      padding: const EdgeInsets.all(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1.26,
                child: imageUrl.isEmpty
                    ? ColoredBox(
                        color: p.inputFill,
                        child: Icon(AppIcons.image, color: p.textHint),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => ColoredBox(color: p.inputFill),
                        errorWidget: (_, __, ___) => ColoredBox(
                          color: p.inputFill,
                          child: Icon(AppIcons.image, color: p.textHint),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.titleText.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 15.5,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${post.location?.city ?? post.constituency ?? post.category?.name ?? 'Local'} • ${timeago.format(post.createdAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.metaText.copyWith(
                color: p.textHint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
