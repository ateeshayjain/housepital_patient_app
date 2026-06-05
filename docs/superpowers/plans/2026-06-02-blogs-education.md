# Blogs / Education Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a care-education articles section — a list of articles served from the backend with a demo fallback, each opening a markdown-rendered detail view.

**Architecture:** Vertical slice mirroring the app's existing pattern: `Article` model → `getArticles`/`getArticle` on `IApiService` (+ `ApiService` impl + mocks) → `BlogProvider` (ChangeNotifier with demo fallback) → list + detail screens. Entry via a "Care Guides" tile in the Home Book-Services grid and routes `/articles` + `/article`. One new dependency: `flutter_markdown`.

**Tech Stack:** Flutter/Dart, Provider, `IApiService`, `DemoData`, `flutter_markdown`.

**Base branch:** new feature branch `feat/blogs-education` off the current working branch (NOT off feat/home-layout-b — keep independent).

---

## File Structure

- **Create:** `lib/models/article.dart` — `Article` data model (+ JSON)
- **Create:** `lib/providers/blog_provider.dart` — list/detail state, demo fallback
- **Create:** `lib/screens/articles/article_list_screen.dart`
- **Create:** `lib/screens/articles/article_detail_screen.dart`
- **Modify:** `lib/services/i_api_service.dart` — add `getArticles`, `getArticle`
- **Modify:** `lib/services/api_service.dart` — implement both (with `@override`)
- **Modify:** `lib/data/demo_data.dart` — add `static List<Article> get articles`
- **Modify:** `lib/main.dart` — register `BlogProvider` in MultiProvider + routes `/articles`, `/article`
- **Modify:** `lib/screens/home/home_screen.dart` — add "Care Guides" tile to the quick-actions grid (coordinate: this file is also touched by the Home Layout B plan; this plan's change is additive — one grid item — and should be applied AFTER home-layout-b merges, or as a tiny follow-up)
- **Modify:** `pubspec.yaml` — add `flutter_markdown`
- **Modify test mocks:** `test/providers/mock_api_service.dart` + `test/_mocks/*` — add the two methods (they `extends ApiService`, so they inherit automatically — verify, only add overrides if a mock `implements IApiService`)
- **Tests:** `test/models/article_test.dart`, `test/providers/blog_provider_test.dart`, `test/screens/articles/article_list_test.dart`

---

## Task 1: Add the `flutter_markdown` dependency

**Files:** Modify `pubspec.yaml`

- [ ] **Step 1: Add `flutter_markdown` under dependencies** (latest compatible — let pub resolve).

```yaml
  flutter_markdown: ^0.7.0
```

- [ ] **Step 2: Resolve.**

Run: `flutter pub get`
Expected: "Got dependencies!" with flutter_markdown resolved. Note the resolved version.

- [ ] **Step 3: Commit.**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add flutter_markdown for article bodies"
```

---

## Task 2: `Article` model (TDD)

**Files:** Create `lib/models/article.dart`; Test `test/models/article_test.dart`

- [ ] **Step 1: Write the failing test** for JSON round-trip + readMinutes fallback.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/article.dart';

void main() {
  test('Article.fromJson parses all fields', () {
    final a = Article.fromJson({
      'id': 'a1',
      'title': 'Caring for a bedridden patient',
      'summary': 'Daily basics',
      'body': '# Heading\nText',
      'cover_image_url': 'https://x/y.jpg',
      'category': 'Home Care',
      'read_minutes': 4,
      'published_at': '2026-05-01T00:00:00.000Z',
    });
    expect(a.id, 'a1');
    expect(a.category, 'Home Care');
    expect(a.readMinutes, 4);
    expect(a.publishedAt.year, 2026);
  });

  test('Article.fromJson tolerates missing optional fields', () {
    final a = Article.fromJson({'id': 'a2', 'title': 'T', 'body': 'b'});
    expect(a.summary, '');
    expect(a.readMinutes, isNonNegative);
    expect(a.coverImageUrl, isNull);
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (`article.dart` not found).

Run: `flutter test test/models/article_test.dart -v`
Expected: FAIL (compile error / missing file).

- [ ] **Step 3: Implement `lib/models/article.dart`.** Follow the nullable-tolerant `fromJson` pattern used by existing models (e.g. `models.dart`).

```dart
class Article {
  final String id;
  final String title;
  final String summary;
  final String body; // markdown
  final String? coverImageUrl;
  final String category;
  final int readMinutes;
  final DateTime publishedAt;

  const Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    this.coverImageUrl,
    required this.category,
    required this.readMinutes,
    required this.publishedAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: json['id']?.toString() ?? '',
        title: json['title'] ?? '',
        summary: json['summary'] ?? '',
        body: json['body'] ?? '',
        coverImageUrl: json['cover_image_url'],
        category: json['category'] ?? 'General',
        readMinutes: (json['read_minutes'] as num?)?.toInt() ?? 3,
        publishedAt:
            DateTime.tryParse(json['published_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'body': body,
        'cover_image_url': coverImageUrl,
        'category': category,
        'read_minutes': readMinutes,
        'published_at': publishedAt.toIso8601String(),
      };
}
```

- [ ] **Step 4: Run — expect PASS.**

Run: `flutter test test/models/article_test.dart -v`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/models/article.dart test/models/article_test.dart
git commit -m "feat: Article model with tolerant JSON parsing + tests"
```

---

## Task 3: Demo articles

**Files:** Modify `lib/data/demo_data.dart`

- [ ] **Step 1: Add `static List<Article> get articles`** with 4–5 realistic care guides (import `article.dart`). Titles e.g.: "Caring for a Bedridden Patient at Home", "Post-ICU Recovery: First 30 Days", "Managing Diabetes Diet for Elders", "Preventing Bed Sores", "When to Call Your Health Manager". Each: id, title, summary, a short markdown `body` (a heading + 2-3 bullet points), category, readMinutes, publishedAt.

- [ ] **Step 2: Analyze.**

Run: `flutter analyze lib/data/demo_data.dart`
Expected: No issues.

- [ ] **Step 3: Commit.**

```bash
git add lib/data/demo_data.dart
git commit -m "feat: demo articles for offline fallback"
```

---

## Task 4: API methods on the interface + impl

**Files:** Modify `lib/services/i_api_service.dart`, `lib/services/api_service.dart`

- [ ] **Step 1: Add to `IApiService`** (under a new `// ── Articles ──` section):

```dart
  Future<List<Article>> getArticles({String? category});
  Future<Article> getArticle(String id);
```
(import `../models/article.dart` in the interface file.)

- [ ] **Step 2: Implement in `ApiService`** with `@override`, following the existing `_get` + `queryParams` pattern (NOT string concat):

```dart
  @override
  Future<List<Article>> getArticles({String? category}) async {
    final qp = <String, String>{};
    if (category != null) qp['category'] = category;
    final data = await _get('/articles', queryParams: qp.isEmpty ? null : qp);
    return (data['articles'] as List).map((a) => Article.fromJson(a)).toList();
  }

  @override
  Future<Article> getArticle(String id) async {
    final data = await _get('/articles/$id');
    return Article.fromJson(data['article'] ?? data);
  }
```

- [ ] **Step 3: Analyze + run service tests** (mocks extend ApiService → inherit automatically).

Run: `flutter analyze lib/services/ && flutter test test/services/api_service_test.dart`
Expected: 0 issues; tests pass. If a mock `implements IApiService` directly, add the two overrides there.

- [ ] **Step 4: Commit.**

```bash
git add lib/services/i_api_service.dart lib/services/api_service.dart
git commit -m "feat: getArticles/getArticle on IApiService + impl"
```

---

## Task 5: `BlogProvider` with demo fallback (TDD)

**Files:** Create `lib/providers/blog_provider.dart`; Test `test/providers/blog_provider_test.dart`

- [ ] **Step 1: Write failing tests** — (a) success sets list; (b) API throws → falls back to `DemoData.articles`, list non-empty, error null; (c) `loadArticle` sets `selected`. Mirror `medication_provider_test.dart`'s mock setup.

```dart
test('loadArticles success sets list', () async {
  final p = BlogProvider(FakeApi(success: true));
  await p.loadArticles();
  expect(p.articles, isNotEmpty);
  expect(p.error, isNull);
});

test('loadArticles API error falls back to demo data', () async {
  final p = BlogProvider(FakeApi(success: false));
  await p.loadArticles();
  expect(p.articles, isNotEmpty); // demo fallback
  expect(p.isLoading, isFalse);
});
```

- [ ] **Step 2: Run — expect FAIL.**

Run: `flutter test test/providers/blog_provider_test.dart -v`
Expected: FAIL (provider missing).

- [ ] **Step 3: Implement `BlogProvider`** mirroring `MedicationProvider`: `IApiService` dep, `_articles`, `_selected`, `_isLoading`, `_error`, `loadArticles({category})`, `loadArticle(id)`. On `ApiException`/error: `Log.warn(...)`, set `_articles = DemoData.articles`, clear error (recoverable demo path), `notifyListeners()`.

- [ ] **Step 4: Run — expect PASS.**

Run: `flutter test test/providers/blog_provider_test.dart -v`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/providers/blog_provider.dart test/providers/blog_provider_test.dart
git commit -m "feat: BlogProvider with demo fallback + tests"
```

---

## Task 6: Article list screen

**Files:** Create `lib/screens/articles/article_list_screen.dart`; Test `test/screens/articles/article_list_test.dart`

- [ ] **Step 1: Write a widget test** — pump with a `BlogProvider` seeded from demo data; assert article titles render as cards and tapping one pushes `/article`. Use a `NavigatorObserver` mock to verify the route.

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement the screen** — `AppBar('Care Guides')`, `Consumer<BlogProvider>`, shimmer skeleton while loading (reuse the Shimmer pattern from batch 4 screens), `ListView` of cards (cover image via `CachedNetworkImage` if used elsewhere or `Image.network` with errorBuilder, title, category chip, "{readMinutes} min read"). Tap → `Navigator.pushNamed(context, '/article', arguments: article.id)`. Trigger `loadArticles()` in `initState` via `context.read`. Add `Semantics`/`labelText` per the a11y bar.

- [ ] **Step 4: Run — expect PASS.** Then `flutter analyze` the new files.

- [ ] **Step 5: Commit.**

```bash
git add lib/screens/articles/article_list_screen.dart test/screens/articles/article_list_test.dart
git commit -m "feat: article list screen + test"
```

---

## Task 7: Article detail screen (markdown)

**Files:** Create `lib/screens/articles/article_detail_screen.dart`

- [ ] **Step 1: Implement** — takes an article id argument; reads from `BlogProvider` (if the article is already in the loaded list use it, else `loadArticle(id)`); renders cover image + title + category + `MarkdownBody(data: article.body)` from `flutter_markdown` inside a scroll view; a share action (reuse `SharePlus.instance.share` pattern from invoice_detail). Friendly error if the article can't load (no raw exception text — per the audit rule).

- [ ] **Step 2: Analyze.**

Run: `flutter analyze lib/screens/articles/`
Expected: No issues.

- [ ] **Step 3: Commit.**

```bash
git add lib/screens/articles/article_detail_screen.dart
git commit -m "feat: article detail screen with markdown body"
```

---

## Task 8: Wire provider + routes + Home entry tile

**Files:** Modify `lib/main.dart`, `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Register `BlogProvider`** in the `MultiProvider` list in `main.dart` (`create: (_) => BlogProvider(apiService)`).

- [ ] **Step 2: Add routes** in `onGenerateRoute`:

```dart
case '/articles':
  return MaterialPageRoute(builder: (_) => const ArticleListScreen());
case '/article':
  final id = settings.arguments;
  if (id is! String) return _argErrorRoute(); // reuse existing guard helper
  return MaterialPageRoute(builder: (_) => ArticleDetailScreen(articleId: id));
```

- [ ] **Step 3: Add a "Care Guides" tile** to the Home quick-actions grid (`_buildQuickActionsGrid`) → `Navigator.pushNamed(context, '/articles')`, icon `Icons.menu_book`. NOTE: home_screen.dart is also edited by the Home Layout B plan — apply this tile addition cleanly on top of whatever order Layout B produced (it's a single grid entry, additive).

- [ ] **Step 4: Analyze + targeted tests.**

Run: `flutter analyze && flutter test test/screens/articles/ test/providers/blog_provider_test.dart`
Expected: 0 issues; pass.

- [ ] **Step 5: Commit.**

```bash
git add lib/main.dart lib/screens/home/home_screen.dart
git commit -m "feat: wire BlogProvider, /articles routes, Care Guides home tile"
```

---

## Task 9: Full verification

- [ ] **Step 1:** `flutter analyze` → No issues.
- [ ] **Step 2:** `flutter test` → green (baseline + new tests).
- [ ] **Step 3:** `flutter build web --release` → clean.
- [ ] **Step 4:** Smoke: open app → Home → "Care Guides" tile → list renders (demo articles offline) → tap → markdown detail renders.
- [ ] **Step 5:** Final commit of any test-mock updates.

---

## Done criteria
- `flutter analyze` = 0 issues; full suite green; web build clean
- Care Guides reachable from Home; list shows demo articles offline; detail renders markdown
- Backend `/articles` consumed when reachable, demo fallback when not
