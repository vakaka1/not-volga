import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_volga/models/news_item.dart';
import 'package:not_volga/screens/news_screen.dart';
import 'package:not_volga/services/news_service.dart';

class MockNewsService extends NewsService {
  final List<NewsItem> stubNews;

  MockNewsService(this.stubNews);

  @override
  Future<List<NewsItem>> fetchNews({int limit = NewsService.defaultLimit}) async {
    return stubNews.take(limit).toList();
  }
}

void main() {
  group('NewsScreen Widget Tests', () {
    final testNews = [
      const NewsItem(
        title: 'Экономия почти 850 тысяч рублей по пересадочному тарифу',
        announce:
            'С начала года пассажиры «Транспорта Верхневолжья» сэкономили почти 850 тысяч рублей по пересадочному тарифу',
        date: '30 августа 2026',
        url: 'https://tvercard.ru/sobytiya/test1',
      ),
      const NewsItem(
        title: 'Открыта покупка школьного абонемента на сентябрь',
        announce: 'Школьные транспортные карты начнут действовать с 1 сентября.',
        date: '29 августа 2026',
        url: 'https://tvercard.ru/sobytiya/test2',
      ),
    ];

    testWidgets('Displays header "События" and full-width plain news list',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NewsScreen(newsService: MockNewsService(testNews)),
        ),
      );

      await tester.pumpAndSettle();

      // Top title "События" is present
      expect(find.text('События'), findsOneWidget);

      // No refresh icon button
      expect(find.byIcon(Icons.refresh), findsNothing);

      // Bold Title, regular text, grey date are present
      expect(
        find.text('Экономия почти 850 тысяч рублей по пересадочному тарифу'),
        findsOneWidget,
      );
      expect(
        find.text(
          'С начала года пассажиры «Транспорта Верхневолжья» сэкономили почти 850 тысяч рублей по пересадочному тарифу',
        ),
        findsOneWidget,
      );
      expect(find.text('30 августа 2026'), findsOneWidget);

      expect(
        find.text('Открыта покупка школьного абонемента на сентябрь'),
        findsOneWidget,
      );
      expect(find.text('29 августа 2026'), findsOneWidget);
    });
  });
}
