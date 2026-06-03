/// A care-education article rendered from a markdown [body].
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
