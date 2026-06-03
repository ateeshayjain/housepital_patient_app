import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/article.dart';
import 'package:housepital_patient/providers/blog_provider.dart';
import 'package:housepital_patient/services/api_service.dart';

/// Lightweight fake implementing only the article methods used by BlogProvider.
class _FakeApi extends ApiService {
  _FakeApi({required this.success});

  final bool success;
  int getArticlesCalls = 0;
  int getArticleCalls = 0;

  static final _sample = Article(
    id: 'srv1',
    title: 'Server article',
    summary: 'from api',
    body: '# Body',
    coverImageUrl: null,
    category: 'Home Care',
    readMinutes: 2,
    publishedAt: DateTime(2026, 5, 1),
  );

  @override
  Future<List<Article>> getArticles({String? category}) async {
    getArticlesCalls++;
    if (!success) {
      throw ApiException(statusCode: 500, message: 'boom');
    }
    return [_sample];
  }

  @override
  Future<Article> getArticle(String id) async {
    getArticleCalls++;
    if (!success) {
      throw ApiException(statusCode: 500, message: 'boom');
    }
    return _sample;
  }
}

void main() {
  test('loadArticles success sets list from API', () async {
    final api = _FakeApi(success: true);
    final p = BlogProvider(api);
    await p.loadArticles();
    expect(p.articles, isNotEmpty);
    expect(p.articles.first.id, 'srv1');
    expect(p.error, isNull);
    expect(p.isLoading, isFalse);
  });

  test('loadArticles API error falls back to demo data', () async {
    final p = BlogProvider(_FakeApi(success: false));
    await p.loadArticles();
    expect(p.articles, isNotEmpty); // demo fallback
    expect(p.isLoading, isFalse);
    expect(p.error, isNull); // recoverable demo path
  });

  test('loadArticle success sets selected', () async {
    final p = BlogProvider(_FakeApi(success: true));
    await p.loadArticle('srv1');
    expect(p.selected, isNotNull);
    expect(p.selected!.id, 'srv1');
  });

  test('loadArticle uses already-loaded article without hitting API again',
      () async {
    final api = _FakeApi(success: true);
    final p = BlogProvider(api);
    await p.loadArticles();
    final callsAfterList = api.getArticleCalls;
    await p.loadArticle('srv1');
    expect(p.selected!.id, 'srv1');
    expect(api.getArticleCalls, callsAfterList); // served from cache
  });

  test('loadArticle falls back to demo data on API error', () async {
    final p = BlogProvider(_FakeApi(success: false));
    await p.loadArticle('art_bedridden_care');
    expect(p.selected, isNotNull);
    expect(p.selected!.id, 'art_bedridden_care');
  });
}
