import 'package:flutter_test/flutter_test.dart';
import 'package:news_app/providers/reporter_provider.dart';

void main() {
  group('ReporterProvider', () {
    test('status counts are zero before posts are loaded', () {
      final provider = ReporterProvider();
      expect(provider.pendingCount, 0);
      expect(provider.approvedCount, 0);
      expect(provider.rejectedCount, 0);
      expect(provider.draftCount, 0);
    });

    test('initial state is not loading with empty posts', () {
      final provider = ReporterProvider();
      expect(provider.loading, isFalse);
      expect(provider.myPosts, isEmpty);
      expect(provider.stats, isNull);
    });

    test('reset clears cached posts and stats', () {
      final provider = ReporterProvider();
      provider.reset();
      expect(provider.myPosts, isEmpty);
      expect(provider.stats, isNull);
      expect(provider.editingPost, isNull);
      expect(provider.error, isNull);
    });
  });
}
