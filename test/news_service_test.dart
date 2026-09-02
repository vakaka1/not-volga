import 'package:flutter_test/flutter_test.dart';
import 'package:not_volga/models/news_item.dart';
import 'package:not_volga/services/news_service.dart';

void main() {
  group('NewsService and Parser Tests', () {
    const sampleHtml = '''
<!DOCTYPE html>
<html>
<head><title>События</title></head>
<body>
  <div class="row">
    <div id="comp_test">
      <a href="/sobytiya/ekonomiya-pochti-850-tysyach-rubley-po-peresadochnomu-tarifu/" class="event-item ">
        <h3 class="heading">Экономия почти 850 тысяч рублей по пересадочному тарифу</h3>
        <div class="announce">
          С начала года пассажиры «Транспорта Верхневолжья» сэкономили почти 850 тысяч рублей по пересадочному тарифу
        </div>
        <div class="date">
          30 августа 2026
        </div>
        <span class="news-category" style="border-color: blue">
          Новости транспорта
        </span>
      </a>
      <a href="/sobytiya/otkryta-pokupka-shkolnogo-abonementa-na-sentyabr-/" class="event-item ">
        <h3 class="heading">Открыта покупка школьного абонемента на сентябрь</h3>
        <div class="announce">
          Школьные транспортные карты для проезда в автобусах Твери начнут действовать вновь с 1 сентября.
        </div>
        <div class="date">
          29 августа 2026
        </div>
      </a>
    </div>
  </div>
</body>
</html>
''';

    test('parseNewsHtml correctly parses event items from HTML', () {
      final items = NewsService.parseNewsHtml(sampleHtml, limit: 9);

      expect(items.length, 2);

      expect(items[0].title, 'Экономия почти 850 тысяч рублей по пересадочному тарифу');
      expect(
        items[0].announce,
        'С начала года пассажиры «Транспорта Верхневолжья» сэкономили почти 850 тысяч рублей по пересадочному тарифу',
      );
      expect(items[0].date, '30 августа 2026');
      expect(
        items[0].url,
        'https://tvercard.ru/sobytiya/ekonomiya-pochti-850-tysyach-rubley-po-peresadochnomu-tarifu/',
      );

      expect(items[1].title, 'Открыта покупка школьного абонемента на сентябрь');
      expect(
        items[1].announce,
        'Школьные транспортные карты для проезда в автобусах Твери начнут действовать вновь с 1 сентября.',
      );
      expect(items[1].date, '29 августа 2026');
    });

    test('parseNewsHtml respects limit parameter (9 news max)', () {
      final items = NewsService.parseNewsHtml(sampleHtml, limit: 1);
      expect(items.length, 1);
      expect(items[0].title, 'Экономия почти 850 тысяч рублей по пересадочному тарифу');
    });

    test('Fallback news contains exactly 9 latest official items', () {
      expect(NewsService.fallbackNews.length, 9);
      expect(
        NewsService.fallbackNews[0].title,
        'Экономия почти 850 тысяч рублей по пересадочному тарифу',
      );
      expect(NewsService.fallbackNews[0].date, '30 августа 2026');
    });

    test('NewsItem model serialization and equality', () {
      const item = NewsItem(
        title: 'Заголовок',
        announce: 'Текст',
        date: '01 января 2026',
        url: 'https://tvercard.ru/sobytiya/test',
      );

      final json = item.toJson();
      final fromJson = NewsItem.fromJson(json);

      expect(fromJson, equals(item));
      expect(fromJson.hashCode, equals(item.hashCode));
    });
  });
}
