import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/article.dart';
import 'package:housepital_patient/providers/blog_provider.dart';
import 'package:housepital_patient/screens/articles/article_list_screen.dart';
import 'package:housepital_patient/services/api_service.dart';

/// Fake API that always fails so BlogProvider falls back to demo articles.
class _OfflineApi extends ApiService {
  @override
  Future<List<Article>> getArticles({String? category}) async {
    throw ApiException(statusCode: 500, message: 'offline');
  }
}

class _RouteObserver extends NavigatorObserver {
  final pushedRoutes = <String?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}

Widget _host(BlogProvider provider, _RouteObserver observer) {
  return ChangeNotifierProvider<BlogProvider>.value(
    value: provider,
    child: MaterialApp(
      navigatorObservers: [observer],
      home: const ArticleListScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('article detail')),
      ),
    ),
  );
}

void main() {
  testWidgets('renders demo article titles as cards', (tester) async {
    final provider = BlogProvider(_OfflineApi());
    final observer = _RouteObserver();
    await tester.pumpWidget(_host(provider, observer));
    await tester.pumpAndSettle();

    expect(find.text('Care Guides'), findsOneWidget);
    expect(find.text(DemoData.articles.first.title), findsOneWidget);
  });

  testWidgets('tapping an article pushes /article with its id', (tester) async {
    final provider = BlogProvider(_OfflineApi());
    final observer = _RouteObserver();
    await tester.pumpWidget(_host(provider, observer));
    await tester.pumpAndSettle();

    await tester.tap(find.text(DemoData.articles.first.title));
    await tester.pumpAndSettle();

    expect(observer.pushedRoutes, contains('/article'));
  });
}
