import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/news_provider.dart';

/// Routes feature categories to dedicated screens; others filter the main feed.
Future<void> openCategorySlug(
  BuildContext context,
  String slug, {
  NewsProvider? news,
}) async {
  final normalized = slug.trim().toLowerCase();
  if (normalized == 'sports') {
    if (context.mounted) context.push('/sports');
    return;
  }
  if (normalized == 'weather') {
    if (context.mounted) context.push('/weather');
    return;
  }

  final provider = news ?? context.read<NewsProvider>();
  Category? match;
  for (final c in provider.categories) {
    if (c.slug.toLowerCase() == normalized) {
      match = c;
      break;
    }
  }

  if (match == null) {
    await provider.loadCategories();
    for (final c in provider.categories) {
      if (c.slug.toLowerCase() == normalized) {
        match = c;
        break;
      }
    }
  }

  if (match == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This category is not available yet. Pull to refresh and try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }
  await provider.selectCategory(match.id);
  if (context.mounted) context.go('/feed');
}

/// Handles Top News (`null` id) and feature slugs from category pickers.
Future<void> openCategoryById(
  BuildContext context,
  String? categoryId, {
  NewsProvider? news,
}) async {
  if (categoryId == null) {
    final provider = news ?? context.read<NewsProvider>();
    await provider.selectCategory(null);
    return;
  }

  final provider = news ?? context.read<NewsProvider>();
  for (final c in provider.categories) {
    if (c.id == categoryId) {
      await openCategorySlug(context, c.slug, news: provider);
      return;
    }
  }
  await provider.selectCategory(categoryId);
  if (context.mounted) context.go('/feed');
}
