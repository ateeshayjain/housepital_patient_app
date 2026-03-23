import 'package:flutter/material.dart';
import '../config/theme.dart';

/// A reusable infinite-scroll paginated list with pull-to-refresh,
/// bottom loading spinner, "no more items" indicator, and error retry.
class PaginatedListView<T> extends StatefulWidget {
  /// Fetches a page of items. Return an empty list when no more data.
  final Future<List<T>> Function(int page, int pageSize) fetchPage;

  /// Builds a widget for each item.
  final Widget Function(T item) itemBuilder;

  /// Widget to show when the list is completely empty (page 1 returns []).
  final Widget? emptyWidget;

  /// Number of items per page.
  final int pageSize;

  const PaginatedListView({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    this.emptyWidget,
    this.pageSize = 20,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final List<T> _items = [];
  final ScrollController _scrollController = ScrollController();

  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  bool _initialLoad = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final newItems =
          await widget.fetchPage(_currentPage, widget.pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(newItems);
        _hasMore = newItems.length >= widget.pageSize;
        _currentPage++;
        _isLoading = false;
        _initialLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _initialLoad = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _currentPage = 1;
      _hasMore = true;
      _error = null;
    });
    await _loadPage();
  }

  @override
  Widget build(BuildContext context) {
    // Initial loading
    if (_initialLoad && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Empty state
    if (_items.isEmpty && !_isLoading && _error == null) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: HousepitalColors.orange,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: widget.emptyWidget ??
                  const Center(
                    child: Text(
                      'No items found',
                      style: TextStyle(
                        fontSize: 15,
                        color: HousepitalColors.greyLight,
                      ),
                    ),
                  ),
            ),
          ],
        ),
      );
    }

    // Error on initial load (no items yet)
    if (_items.isEmpty && _error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: HousepitalColors.error),
            const SizedBox(height: 12),
            const Text('Something went wrong',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                  foregroundColor: HousepitalColors.orange),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: HousepitalColors.orange,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + 1, // +1 for footer
        itemBuilder: (context, index) {
          if (index < _items.length) {
            return widget.itemBuilder(_items[index]);
          }

          // Footer: loading / error / no more items
          if (_isLoading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          if (_error != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: TextButton.icon(
                  onPressed: _loadPage,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Tap to retry'),
                  style: TextButton.styleFrom(
                      foregroundColor: HousepitalColors.error),
                ),
              ),
            );
          }

          if (!_hasMore && _items.isNotEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No more items',
                  style: TextStyle(
                    fontSize: 13,
                    color: HousepitalColors.greyLight,
                  ),
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
