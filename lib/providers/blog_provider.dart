import 'package:flutter/foundation.dart';
import '../data/demo_data.dart';
import '../models/article.dart';
import '../services/api_service.dart';

/// Provides care-education articles with a demo-data fallback when the
/// backend is unreachable. Mirrors [MedicationProvider]'s offline pattern.
class BlogProvider extends ChangeNotifier {
  final ApiService _apiService;

  List<Article> _articles = [];
  Article? _selected;
  bool _isLoading = false;
  String? _error;

  BlogProvider(this._apiService);

  // Getters
  List<Article> get articles => _articles;
  Article? get selected => _selected;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load the list of articles, falling back to demo data on any error.
  Future<void> loadArticles({String? category}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final list = await _apiService
          .getArticles(category: category)
          .timeout(const Duration(seconds: 5));
      _articles = list;
      _error = null;
    } catch (e) {
      debugPrint('Articles API unavailable, using demo data: $e');
      _articles = _filtered(DemoData.articles, category);
      _error = null; // recoverable demo path
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load a single article. Serves from the already-loaded list when possible,
  /// otherwise fetches it, falling back to demo data on error.
  Future<void> loadArticle(String id) async {
    // Serve from cache if already loaded.
    final cached = _articles.where((a) => a.id == id).toList();
    if (cached.isNotEmpty) {
      _selected = cached.first;
      _error = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selected =
          await _apiService.getArticle(id).timeout(const Duration(seconds: 5));
      _error = null;
    } catch (e) {
      debugPrint('Article API unavailable, using demo data: $e');
      final demo = DemoData.articles.where((a) => a.id == id).toList();
      _selected = demo.isNotEmpty ? demo.first : null;
      _error = _selected == null ? 'Article not found' : null;
    }

    _isLoading = false;
    notifyListeners();
  }

  List<Article> _filtered(List<Article> source, String? category) {
    if (category == null) return source;
    return source.where((a) => a.category == category).toList();
  }
}
