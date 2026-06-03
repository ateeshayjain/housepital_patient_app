import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme.dart';
import '../../models/article.dart';
import '../../providers/blog_provider.dart';

/// Renders a single care guide: cover image, title, category and a
/// markdown-rendered body.
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
      appBar: AppBar(
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
            return const Center(child: CircularProgressIndicator());
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      article.category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HousepitalColors.greyLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('•',
                        style: TextStyle(color: HousepitalColors.greyLight)),
                    const SizedBox(width: 8),
                    Text(
                      '${article.readMinutes} min read',
                      style: const TextStyle(
                        fontSize: 12,
                        color: HousepitalColors.greyLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  article.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: MarkdownBody(
              data: article.body,
              selectable: true,
            ),
          ),
        ],
      ),
    );
  }
}
