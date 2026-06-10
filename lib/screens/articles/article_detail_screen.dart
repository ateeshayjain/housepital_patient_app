import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../models/article.dart';
import '../../providers/blog_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass.dart';
import 'article_category_style.dart';

/// Renders a single care guide: accent-tinted hero header, an editorial
/// markdown body, and an end-of-article feedback card.
class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({super.key, required this.articleId});

  final String articleId;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BlogProvider>().loadArticle(widget.articleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('Care Guide'),
        actions: [
          Consumer<BlogProvider>(
            builder: (context, provider, _) {
              final article = provider.selected;
              if (article == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share',
                onPressed: () {
                  SharePlus.instance.share(
                    ShareParams(
                      text: '${article.title}\n\n${article.summary}',
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<BlogProvider>(
        builder: (context, provider, _) {
          final article = provider.selected;

          if (provider.isLoading && article == null) {
            return const LoadingWidget();
          }

          if (article == null || article.id != widget.articleId) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'We could not open this care guide. Please go back and try '
                  'again.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return _buildArticle(context, article);
        },
      ),
    );
  }

  Widget _buildArticle(BuildContext context, Article article) {
    final style = ArticleCategoryStyle.of(context, article.category);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.coverImageUrl != null)
            Image.network(
              article.coverImageUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          _HeroHeader(article: article, style: style),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: MarkdownBody(
              data: article.body,
              selectable: true,
              styleSheet: _styleSheet(context, style.accent),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: _HelpfulCard(accent: style.accent),
          ),
        ],
      ),
    );
  }

  /// Editorial typography for the markdown body. Tints (blockquote fill,
  /// borders) all derive from the category accent token so they stay readable
  /// in dark mode.
  MarkdownStyleSheet _styleSheet(BuildContext context, Color accent) {
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    final body = TextStyle(fontSize: 15, height: 1.6, color: context.hc.black);
    return base.copyWith(
      p: body,
      listBullet: TextStyle(fontSize: 15, height: 1.5, color: accent),
      h1: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.3,
        color: context.hc.black,
      ),
      h2: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: context.hc.black,
      ),
      h2Padding: const EdgeInsets.only(top: 16, bottom: 4),
      h3: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: context.hc.black,
      ),
      h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
      blockquote: TextStyle(
        fontSize: 14.5,
        height: 1.5,
        color: context.hc.black,
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      blockquoteDecoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      strong: TextStyle(fontWeight: FontWeight.w700, color: context.hc.black),
    );
  }
}

/// Accent-tinted header block: category chip, headline title and byline meta.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.article, required this.style});

  final Article article;
  final ArticleCategoryStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            style.accent.withValues(alpha: 0.12),
            style.accent.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: ShapeDecoration(
              color: style.accent.withValues(alpha: 0.14),
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(style.icon, size: 13, color: style.accent),
                const SizedBox(width: 5),
                Text(
                  article.category,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: style.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            article.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: context.hc.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${article.category} · ${article.readMinutes} min read · '
            'Housepital Care Team',
            style: TextStyle(fontSize: 12, color: context.hc.grey),
          ),
        ],
      ),
    );
  }
}

/// End-of-article card: thumbs up/down feedback plus a tap-to-call line to
/// the Health Manager.
class _HelpfulCard extends StatefulWidget {
  const _HelpfulCard({required this.accent});

  final Color accent;

  @override
  State<_HelpfulCard> createState() => _HelpfulCardState();
}

class _HelpfulCardState extends State<_HelpfulCard> {
  bool? _helpful; // null = no feedback yet

  void _submit(bool helpful) {
    setState(() => _helpful = helpful);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks for the feedback')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.hc.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hc.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Was this helpful?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.hc.black,
                  ),
                ),
              ),
              _FeedbackButton(
                icon: _helpful == true
                    ? Icons.thumb_up
                    : Icons.thumb_up_outlined,
                label: 'Helpful',
                color: _helpful == true ? widget.accent : context.hc.greyLight,
                onTap: () => _submit(true),
              ),
              const SizedBox(width: 4),
              _FeedbackButton(
                icon: _helpful == false
                    ? Icons.thumb_down
                    : Icons.thumb_down_outlined,
                label: 'Not helpful',
                color:
                    _helpful == false ? widget.accent : context.hc.greyLight,
                onTap: () => _submit(false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: context.hc.divider),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  launchUrl(Uri.parse('tel:${AppConstants.supportPhone}')),
              icon: const Icon(Icons.support_agent, size: 18),
              label: const Text('Talk to your Health Manager'),
              style: TextButton.styleFrom(
                foregroundColor: context.hc.orangeText,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: color,
        tooltip: label,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: onTap,
      ),
    );
  }
}
