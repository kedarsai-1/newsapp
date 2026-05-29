import 'package:flutter_test/flutter_test.dart';
import 'package:news_app/models/models.dart';

void main() {
  group('User model', () {
    test('fromJson parses role flags', () {
      final user = User.fromJson({
        '_id': 'u1',
        'name': 'Reporter One',
        'email': 'rep@test.com',
        'role': 'reporter',
      });

      expect(user.id, 'u1');
      expect(user.isReporter, isTrue);
      expect(user.isAdmin, isFalse);
    });
  });

  group('Category model', () {
    test('fromJson uses defaults for missing fields', () {
      final cat = Category.fromJson({
        '_id': 'c1',
        'name': 'Sports',
        'slug': 'sports',
      });

      expect(cat.icon, '📰');
      expect(cat.color, '#1D9E75');
    });
  });

  group('NewsPost model', () {
    test('fromJson parses nested category and location', () {
      final post = NewsPost.fromJson({
        '_id': 'p1',
        'title': 'Test headline',
        'body': 'Body text',
        'status': 'approved',
        'views': 42,
        'likes': 7,
        'createdAt': '2024-06-01T10:00:00.000Z',
        'category': {
          '_id': 'c1',
          'name': 'Politics',
          'slug': 'politics',
        },
        'location': {
          'latitude': 16.5,
          'longitude': 80.6,
          'city': 'Vijayawada',
        },
      });

      expect(post.title, 'Test headline');
      expect(post.category?.name, 'Politics');
      expect(post.location?.city, 'Vijayawada');
      expect(post.hasImages, isFalse);
    });

    test('displayTime prefers sourcePublishedAt', () {
      final published = DateTime(2024, 1, 1);
      final created = DateTime(2024, 6, 1);
      final post = NewsPost(
        id: 'p1',
        title: 't',
        body: 'b',
        status: 'approved',
        sourcePublishedAt: published,
        createdAt: created,
      );
      expect(post.displayTime, published);
    });
  });
}
