import 'package:flutter/material.dart';
import '../models/news_item.dart';
import '../services/news_service.dart';
import '../theme/app_colors.dart';

class NewsScreen extends StatefulWidget {
  final NewsService? newsService;

  const NewsScreen({
    super.key,
    this.newsService,
  });

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late final NewsService _newsService;
  late Future<List<NewsItem>> _newsFuture;

  @override
  void initState() {
    super.initState();
    _newsService = widget.newsService ?? NewsService();
    _newsFuture = _newsService.fetchNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        centerTitle: false,
        title: const Text(
          'События',
          style: TextStyle(
            fontFamily: 'NotoSans',
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: FutureBuilder<List<NewsItem>>(
        future: _newsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          final news = snapshot.data ?? [];
          if (news.isEmpty) {
            return const SizedBox.shrink();
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: news.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = news[index];
              return _buildNewsItem(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildNewsItem(NewsItem item) {
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: () {
          // Заглушка для нажатия новости - кнопка прожимается
        },
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок жирным
              Text(
                item.title,
                style: const TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
              if (item.announce.isNotEmpty) ...[
                const SizedBox(height: 8),
                // Текст анонса
                Text(
                  item.announce,
                  style: const TextStyle(
                    fontFamily: 'NotoSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ],
              if (item.date.isNotEmpty) ...[
                const SizedBox(height: 8),
                // Дата (не серая)
                Text(
                  item.date,
                  style: const TextStyle(
                    fontFamily: 'NotoSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
      ),
    );
  }
}
