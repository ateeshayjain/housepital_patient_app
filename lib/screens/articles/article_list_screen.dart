import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/app_colors.dart';
import '../../models/article.dart';
import '../../providers/blog_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass.dart';
import 'article_category_style.dart';

/// Lists care-education articles ("Care Guides"). Tapping one opens the
/// markdown detail screen.
///
/// Editorial layout: a hero "featured" card for the newest guide, a category
/// filter row, then compact cards with an accent-tinted cover tile per
/// category (see [ArticleCategoryStyle]).
class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key});

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  /// null == "All" — featured hero shows only in this state.
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BlogProvider>().loadArticles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(title: const Text('Care Guides')),
      body: Consumer<BlogProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.articles.isEmpty) {
            return _buildSkeleton();
          }
          if (provider.articles.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No care guides available right now. Please check back soon.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final categories = _categories(provider.articles);
          final visible = _selectedCategory == null
              ? provider.articles
              : provider.articles
                  .where((a) => a.category == _selectedCategory)
                  .toList();
          final showFeatured = _selectedCategory == null && visible.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _CategoryFilterRow(
                categories: categories,
                selected: _selectedCategory,
                onSelected: (c) => setState(() => _selectedCategory = c),
              ),
              const SizedBox(height: 16),
              if (showFeatured) ...[
                _FeaturedArticleCard(article: visible.first),
                const SizedBox(height: 16),
              ],
              // HousepitalCard carries the card theme's vertical-8 margin,
              // so no explicit separator is needed between list cards.
              for (final article
                  in showFeatured ? visible.skip(1) : visible)
                _ArticleCard(article: article),
            ],
          );
        },
      ),
    );
  }

  /// Distinct categories in first-seen order.
  List<String> _categories(List<Article> articles) {
    final seen = <String>{};
    final out = <String>[];
    for (final a in articles) {
      if (seen.add(a.category)) out.add(a.category);
    }
    return out;
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: context.hc.divider,
      highlightColor: context.hc.greyLighter,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          height: 96,
          decoration: BoxDecoration(
            color: context.hc.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of category filter chips. The selected chip wears the
/// category's accent; "All" wears the brand orange.
class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FilterChip(
              label: 'All',
              accent: context.hc.orange,
              isSelected: selected == null,
              onTap: () => onSelected(null),
            );
          }
          final category = categories[index - 1];
          return _FilterChip(
            label: category,
            accent: ArticleCategoryStyle.of(context, category).accent,
            isSelected: selected == category,
            onTap: () => onSelected(category),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Filter by $label',
      child: Material(
        color: isSelected ? accent.withValues(alpha: 0.14) : context.hc.white,
        shape: StadiumBorder(
          side: BorderSide(color: isSelected ? accent : context.hc.divider),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? accent : context.hc.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero-style card for the top guide when no filter is active: full-width
/// accent gradient with an icon watermark and a FEATURED micro-label.
class _FeaturedArticleCard extends StatelessWidget {
  const _FeaturedArticleCard({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final style = ArticleCategoryStyle.of(context, article.category);
    return Semantics(
      button: true,
      label: 'Featured. ${article.title}. ${article.category}. '
          '${article.readMinutes} minute read.',
      child: Material(
        color: context.hc.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              Navigator.pushNamed(context, '/article', arguments: article.id),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: style.accent.withValues(alpha: 0.30)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  style.accent.withValues(alpha: 0.12),
                  style.accent.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Icon watermark, clipped by the card bounds.
                  Positioned(
                    right: -18,
                    bottom: -22,
                    child: Icon(
                      style.icon,
                      size: 120,
                      color: style.accent.withValues(alpha: 0.10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FEATURED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: style.accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            color: context.hc.black,
                          ),
                        ),
                        if (article.summary.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            article.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: context.hc.grey,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _CategoryChip(
                              label: article.category,
                              accent: style.accent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '· ${article.readMinutes} min read',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.hc.greyLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact list card: accent-tinted 64px cover tile with the category icon,
/// then title / excerpt / chip-and-read-time footer.
class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final style = ArticleCategoryStyle.of(context, article.category);
    return Semantics(
      button: true,
      label: '${article.title}. ${article.category}. '
          '${article.readMinutes} minute read.',
      // Canonical top-level list card: HousepitalCard (squircle 16, press
      // 0.97) — the featured hero above stays custom by design.
      child: HousepitalCard(
        padding: const EdgeInsets.all(12),
        onTap: () =>
            Navigator.pushNamed(context, '/article', arguments: article.id),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accent "cover" tile — gives every card identity without a
            // photo: subtle tint fill + large category icon.
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: style.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(style.icon, size: 30, color: style.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: context.hc.black,
                    ),
                  ),
                  if (article.summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: context.hc.greyLight,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _CategoryChip(
                        label: article.category,
                        accent: style.accent,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '· ${article.readMinutes} min read',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.hc.greyLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stadium chip tinted with the category accent.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: ShapeDecoration(
        color: accent.withValues(alpha: 0.12),
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }
}
