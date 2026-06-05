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

  test('Article round-trips through toJson/fromJson', () {
    final a = Article.fromJson({
      'id': 'a3',
      'title': 'Round trip',
      'summary': 's',
      'body': 'b',
      'category': 'General',
      'read_minutes': 7,
      'published_at': '2026-01-02T00:00:00.000Z',
    });
    final b = Article.fromJson(a.toJson());
    expect(b.id, a.id);
    expect(b.title, a.title);
    expect(b.readMinutes, a.readMinutes);
    expect(b.publishedAt, a.publishedAt);
  });
}
