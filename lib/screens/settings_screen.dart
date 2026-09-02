import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_assets.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  final String? initialPhoneNumber;

  const SettingsScreen({
    super.key,
    this.initialPhoneNumber,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final String _phoneNumber;
  bool _sakvoyazhEnabled = false;

  static const String privacyPolicyUrl = 'https://tvercard.ru/terms/';
  static const String yandexMapsTermsUrl =
      'https://yandex.ru/legal/maps_termsofuse/ru/';

  @override
  void initState() {
    super.initState();
    _phoneNumber = widget.initialPhoneNumber ?? _generateRandomPhoneNumber();
  }

  static String _generateRandomPhoneNumber() {
    final random = Random();
    final p1 = 900 + random.nextInt(100); // 900-999
    final p2 = 100 + random.nextInt(900); // 100-999
    final p3 = (10 + random.nextInt(90)).toString().padLeft(2, '0'); // 10-99
    final p4 = (10 + random.nextInt(90)).toString().padLeft(2, '0'); // 10-99
    return '+7 $p1 $p2-$p3-$p4';
  }

  Future<void> _openExternalUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const divider = Divider(
      height: 1,
      thickness: 0.8,
      color: Color(0xFFE5E7EB),
    );

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              Padding(
                padding: const EdgeInsets.only(left: 12.0, top: 12.0, bottom: 4.0),
                child: IconButton(
                  icon: Image.asset(
                    AppAssets.icToolbarBack,
                    width: 22,
                    height: 22,
                    color: AppColors.black,
                  ),
                  splashRadius: 24,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),

              // Title "Настройки"
              const Padding(
                padding: EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 20.0),
                child: Text(
                  'Настройки',
                  style: TextStyle(
                    fontFamily: 'NotoSans',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              divider,

              // 1. Номер телефона
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Номер телефона',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 16,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _phoneNumber,
                      style: const TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              divider,

              // 2. Виджет Саквояж
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Виджет Саквояж',
                            style: TextStyle(
                              fontFamily: 'NotoSans',
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Отображать Саквояж\nна экране Сервисы',
                            style: TextStyle(
                              fontFamily: 'NotoSans',
                              fontSize: 14,
                              color: Color(0xFF9E9E9E),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoSwitch(
                      value: _sakvoyazhEnabled,
                      activeTrackColor: const Color(0xFF3B5CFE),
                      onChanged: (bool value) {
                        setState(() {
                          _sakvoyazhEnabled = value;
                        });
                      },
                    ),
                  ],
                ),
              ),

              divider,

              // 3. Политика конфиденциальности
              InkWell(
                onTap: () => _openExternalUrl(privacyPolicyUrl),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Политика конфиденциальности',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),

              divider,

              // 4. Условия использования сервиса Яндекс.Карты
              InkWell(
                onTap: () => _openExternalUrl(yandexMapsTermsUrl),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Условия использования сервиса\nЯндекс.Карты',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ),

              divider,

              // 5. Новые функции (dummy)
              InkWell(
                onTap: () {},
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Новые функции',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),

              divider,

              // 6. Выйти из приложения (dummy)
              InkWell(
                onTap: () {},
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Выйти из приложения',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFD92D20),
                      ),
                    ),
                  ),
                ),
              ),

              divider,

              // 7. Версия 3.4.0
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0),
                child: Center(
                  child: Text(
                    'Версия 3.4.0',
                    style: TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),

              divider,

              // 8. Удалить аккаунт (dummy)
              InkWell(
                onTap: () {},
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Удалить аккаунт',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFD92D20),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
