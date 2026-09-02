class NewsItem {
  final String title;
  final String announce;
  final String date;
  final String url;

  const NewsItem({
    required this.title,
    required this.announce,
    required this.date,
    this.url = '',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'announce': announce,
        'date': date,
        'url': url,
      };

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        title: json['title'] as String? ?? '',
        announce: json['announce'] as String? ?? '',
        date: json['date'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsItem &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          announce == other.announce &&
          date == other.date &&
          url == other.url;

  @override
  int get hashCode => Object.hash(title, announce, date, url);
}
