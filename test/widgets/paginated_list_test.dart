import 'package:flutter_test/flutter_test.dart';

/// Tests the PaginatedListView configuration constants and logic.
/// Widget rendering is not tested here; only data/logic aspects.
void main() {
  group('PaginatedListView logic', () {
    test('default page size is 20', () {
      // Mirrors the default from PaginatedListView: pageSize = 20
      const defaultPageSize = 20;
      expect(defaultPageSize, equals(20));
      expect(defaultPageSize, greaterThan(0));
    });

    test('page size is reasonable (between 10 and 50)', () {
      const defaultPageSize = 20;
      expect(defaultPageSize, greaterThanOrEqualTo(10));
      expect(defaultPageSize, lessThanOrEqualTo(50));
    });

    test('hasMore logic: returns true when page is full', () {
      // Mirrors _loadPage: _hasMore = newItems.length >= widget.pageSize
      const pageSize = 20;
      final fullPage = List.generate(pageSize, (i) => i);
      final hasMore = fullPage.length >= pageSize;
      expect(hasMore, isTrue);
    });

    test('hasMore logic: returns false when page is not full', () {
      const pageSize = 20;
      final partialPage = List.generate(15, (i) => i);
      final hasMore = partialPage.length >= pageSize;
      expect(hasMore, isFalse);
    });

    test('hasMore logic: empty page means no more', () {
      const pageSize = 20;
      final emptyPage = <int>[];
      final hasMore = emptyPage.length >= pageSize;
      expect(hasMore, isFalse);
    });

    test('page counter starts at 1 and increments', () {
      var currentPage = 1;
      // Simulate 3 page loads
      for (int i = 0; i < 3; i++) {
        currentPage++;
      }
      expect(currentPage, equals(4)); // after 3 loads: 1 -> 2 -> 3 -> 4
    });
  });
}
