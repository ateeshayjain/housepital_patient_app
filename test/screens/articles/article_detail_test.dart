import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/article.dart';
import 'package:housepital_patient/providers/blog_provider.dart';
import 'package:housepital_patient/screens/articles/article_detail_screen.dart';
import 'package:housepital_patient/services/api_service.dart';

/// Fake API that always fails so BlogProvider falls back to demo articles.
class _OfflineApi extends ApiService {
  @override
  Future<List<Article>> getArticles({String? category}) async {
    throw ApiException(statusCode: 500, message: 'offline');
  }

  @override
  Future<Article> getArticle(String id) async {
    throw ApiException(statusCode: 500, message: 'offline');
  }
}

Widget _host(BlogProvider provider, String articleId) {
  return ChangeNotifierProvider<BlogProvider>.value(
    value: provider,
    child: MaterialApp(
      home: ArticleDetailScreen(articleId: articleId),
    ),
  );
}

void main() {
  testWidgets('renders the article and the end-of-article helpful card',
      (tester) async {
    final article = DemoData.articles.first;
    final provider = BlogProvider(_OfflineApi());
    await tester.pumpWidget(_host(provider, article.id));
    await tester.pumpAndSettle();

    expect(find.text(article.title), findsOneWidget);
    expect(find.text('Was this helpful?'), findsOneWidget);
    expect(find.text('Talk to your Health Manager'), findsOneWidget);
  });
}
