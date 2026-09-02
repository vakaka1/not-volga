import 'package:flutter/material.dart';

/// Фирменные цвета приложения «Волга», извлечённые из colors.xml оригинального APK.
abstract class AppColors {
  /// Основной синий бренд-цвет (#162F77)
  static const Color primary = Color(0xFF162F77);

  /// Тёмный статус-бар / хедер (#16202E)
  static const Color primaryDark = Color(0xFF16202E);

  /// Акцентный синий (#094C99)
  static const Color accent = Color(0xFF094C99);

  /// Светлый акцент (#3D85CC)
  static const Color accentLight = Color(0xFF3D85CC);

  /// Фоновый цвет основного экрана (#F6F7F9)
  static const Color bgMain = Color(0xFFF6F7F9);

  /// Фоновый цвет плашек и подложек (#F2F4F5)
  static const Color bgGray = Color(0xFFF2F4F5);

  /// Фон номера автобуса (#F2F4F5)
  static const Color bgRegNumber = Color(0xFFF2F4F5);

  /// Градиент плашки билета: начало (#5B677F)
  static const Color bgPlateStart = Color(0xFF5B677F);

  /// Градиент плашки билета: конец (#444D5F)
  static const Color bgPlateEnd = Color(0xFF444D5F);

  /// Основной цвет текста (#111217)
  static const Color textPrimary = Color(0xFF111217);

  /// Вторичный / серый текст (#9B9B9B)
  static const Color textSecondary = Color(0xFF9B9B9B);

  /// Подпись перевозчика (#77829E)
  static const Color busCompanyLabel = Color(0xFF77829E);

  /// Белый цвет (#FFFFFF)
  static const Color white = Color(0xFFFFFFFF);

  /// Чёрный цвет (#000000)
  static const Color black = Color(0xFF000000);
}
