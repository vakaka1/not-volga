import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../models/news_item.dart';

class NewsService {
  static const String newsUrl = 'https://tvercard.ru/sobytiya/';
  static const String baseUrl = 'https://tvercard.ru';
  static const int defaultLimit = 9;

  final http.Client _client;

  NewsService({http.Client? client}) : _client = client ?? http.Client();

  /// Built-in fallback news from tvercard.ru
  static const List<NewsItem> fallbackNews = [
    NewsItem(
      title: 'Экономия почти 850 тысяч рублей по пересадочному тарифу',
      announce:
          'С начала года пассажиры «Транспорта Верхневолжья» сэкономили почти 850 тысяч рублей по пересадочному тарифу',
      date: '30 августа 2026',
      url:
          'https://tvercard.ru/sobytiya/ekonomiya-pochti-850-tysyach-rubley-po-peresadochnomu-tarifu/',
    ),
    NewsItem(
      title: 'Открыта покупка школьного абонемента на сентябрь',
      announce:
          'Школьные транспортные карты для проезда в автобусах Твери, Кимр, Ржева, Старицы, Зубцова, Конаково, Редкино и Новозавидовского начнут действовать вновь с 1 сентября.',
      date: '29 августа 2026',
      url:
          'https://tvercard.ru/sobytiya/otkryta-pokupka-shkolnogo-abonementa-na-sentyabr-/',
    ),
    NewsItem(
      title: 'Перекрытие движения в Зубцове',
      announce:
          '22 августа с 10:00 до 23:00 в связи с проведением городского мероприятия будет перекрыто движение транспорта по ул. Октябрьская (от ул. Ленина до ул. Павлова) в Зубцове',
      date: '21 августа 2026',
      url: 'https://tvercard.ru/sobytiya/perekrytie-dvizheniya-v-zubtsove/',
    ),
    NewsItem(
      title:
          'Сокращен интервал для оплаты проезда за нескольких пассажиров по одной транспортной или банковской карте',
      announce:
          'С 20 августа интервал для оплаты проезда за нескольких пассажиров по одной транспортной или банковской карте сокращён с 2 минут до 40 секунд',
      date: '20 августа 2026',
      url:
          'https://tvercard.ru/sobytiya/sokrashchen-interval-dlya-oplaty-proezda-za-neskolkikh-passazhirov-po-odnoy-transportnoy-ili-bankovs/',
    ),
    NewsItem(
      title: 'Инструктажи перед осенне-зимним сезоном',
      announce: 'У нас начались инструктажи перед осенне-зимним сезоном.',
      date: '18 августа 2026',
      url:
          'https://tvercard.ru/sobytiya/instruktazhi-pered-osenne-zimnim-sezonom-/',
    ),
    NewsItem(
      title: 'Изменение расписания автобусов',
      announce: 'С 17 августа 2026 года изменится расписание движения автобусов',
      date: '15 августа 2026',
      url: 'https://tvercard.ru/sobytiya/izmenenie-raspisaniya-avtobusov/',
    ),
    NewsItem(
      title:
          '1,6 млн поездок по транспортным картам и брелокам «Волга» с начала года',
      announce:
          '1,6 млн поездок совершили пассажиры автобусов «Транспорта Верхневолжья» по транспортным картам и брелокам «Волга» с начала года',
      date: '9 августа 2026',
      url:
          'https://tvercard.ru/sobytiya/1-6-mln-poezdok-po-transportnym-kartam-i-brelokam-volga-s-nachala-goda/',
    ),
    NewsItem(
      title: 'Программа компенсации ипотеки сотрудникам',
      announce:
          '«Верхневолжское АТП» расширило программу компенсации ипотеки сотрудникам',
      date: '6 августа 2026',
      url:
          'https://tvercard.ru/sobytiya/programma-kompensatsii-ipoteki-sotrudnikam/',
    ),
    NewsItem(
      title: 'Изменение схемы движения транспорта',
      announce:
          '30 июля и 2 августа в Твери временно изменится схема движения транспорта',
      date: '29 июля 2026',
      url:
          'https://tvercard.ru/sobytiya/izmenenie-skhemy-dvizheniya-transporta/',
    ),
  ];

  /// Fetches and parses the latest news from https://tvercard.ru/sobytiya/
  Future<List<NewsItem>> fetchNews({int limit = defaultLimit}) async {
    try {
      final response = await _client.get(
        Uri.parse(newsUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Decode body with UTF-8 support
        final htmlContent = utf8.decode(response.bodyBytes, allowMalformed: true);
        final news = parseNewsHtml(htmlContent, limit: limit);
        if (news.isNotEmpty) {
          return news;
        }
      }
      return fallbackNews.take(limit).toList();
    } catch (_) {
      // Return fallback news on network error or timeout
      return fallbackNews.take(limit).toList();
    }
  }

  /// Parses HTML string from tvercard.ru/sobytiya/
  static List<NewsItem> parseNewsHtml(String htmlContent, {int limit = defaultLimit}) {
    final document = html_parser.parse(htmlContent);
    final eventElements = document.querySelectorAll('.event-item');
    final List<NewsItem> results = [];

    for (final element in eventElements) {
      final headingEl = element.querySelector('.heading') ??
          element.querySelector('h3') ??
          element.querySelector('h2');
      final heading = headingEl?.text.trim() ?? '';

      final announceEl = element.querySelector('.announce');
      final announce = announceEl?.text.trim() ?? '';

      final dateEl = element.querySelector('.date');
      final date = dateEl?.text.trim() ?? '';

      var href = element.attributes['href']?.trim() ?? '';
      if (href.isNotEmpty && !href.startsWith('http')) {
        if (!href.startsWith('/')) {
          href = '/$href';
        }
        href = '$baseUrl$href';
      }

      if (heading.isNotEmpty || announce.isNotEmpty) {
        results.add(NewsItem(
          title: heading,
          announce: announce,
          date: date,
          url: href,
        ));
      }

      if (results.length >= limit) {
        break;
      }
    }

    return results;
  }
}
