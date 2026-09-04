import 'dart:math' as math;
import 'package:flutter/animation.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../../models/transport/vehicle_model.dart';

/// Состояние плавной интерполяции движения автобуса в реальном времени
class AnimatedVehicleState {
  Point currentPoint;
  Point startPoint;
  Point targetPoint;
  double currentCourse;
  double startCourse;
  double targetCourse;
  double speedKmh;
  int startTimeMs;
  int durationMs;

  AnimatedVehicleState({
    required this.currentPoint,
    required this.startPoint,
    required this.targetPoint,
    required this.currentCourse,
    required this.startCourse,
    required this.targetCourse,
    required this.speedKmh,
    required this.startTimeMs,
    required this.durationMs,
  });

  void updateTarget(VehicleModel newModel, int now, int duration) {
    startPoint = currentPoint;
    targetPoint = Point(latitude: newModel.lat, longitude: newModel.lng);
    startCourse = currentCourse;
    targetCourse = newModel.course;
    speedKmh = newModel.speed.toDouble();
    startTimeMs = now;
    durationMs = duration;
  }

  void step(int now) {
    if (durationMs <= 0) {
      currentPoint = targetPoint;
      currentCourse = targetCourse;
      return;
    }

    final elapsed = now - startTimeMs;
    final t = (elapsed / durationMs).clamp(0.0, 1.0);

    // Плавная кривая интерполяции перемещения
    final curvedT = Curves.easeInOutCubic.transform(t);

    currentPoint = Point(
      latitude: startPoint.latitude + (targetPoint.latitude - startPoint.latitude) * curvedT,
      longitude: startPoint.longitude + (targetPoint.longitude - startPoint.longitude) * curvedT,
    );

    // Кратчайший поворот угла курса (0..360°)
    double diff = (targetCourse - startCourse) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    currentCourse = (startCourse + diff * t) % 360.0;
    if (currentCourse < 0) currentCourse += 360.0;

    // Экстраполяция (Dead reckoning), если следующий пакет задерживается в сети, но автобус в движении
    if (t >= 1.0 && speedKmh > 5.0 && elapsed < durationMs + 2500) {
      final extraSeconds = (elapsed - durationMs) / 1000.0;
      final meters = (speedKmh / 3.6) * extraSeconds;
      final rad = currentCourse * (math.pi / 180.0);
      final dLat = (meters * math.cos(rad)) / 111111.0;
      final dLng = (meters * math.sin(rad)) /
          (111111.0 * math.cos(currentPoint.latitude * (math.pi / 180.0)));
      currentPoint = Point(
        latitude: targetPoint.latitude + dLat,
        longitude: targetPoint.longitude + dLng,
      );
    }
  }
}

/// Состояние плавной интерполяции положения и направления пользователя в реальном времени
class AnimatedUserState {
  Point currentPoint;
  Point startPoint;
  Point targetPoint;
  double currentHeading;
  double startHeading;
  double targetHeading;
  int startTimeMs;
  int durationMs;

  AnimatedUserState({
    required this.currentPoint,
    required this.startPoint,
    required this.targetPoint,
    required this.currentHeading,
    required this.startHeading,
    required this.targetHeading,
    required this.startTimeMs,
    required this.durationMs,
  });

  void updateTarget(Point newTarget, double newHeading, int now, int duration) {
    startPoint = currentPoint;
    targetPoint = newTarget;
    startHeading = currentHeading;
    targetHeading = newHeading;
    startTimeMs = now;
    durationMs = duration;
  }

  void step(int now) {
    if (durationMs <= 0) {
      currentPoint = targetPoint;
      currentHeading = targetHeading;
      return;
    }

    final elapsed = now - startTimeMs;
    final t = (elapsed / durationMs).clamp(0.0, 1.0);
    final curvedT = Curves.easeOutCubic.transform(t);

    currentPoint = Point(
      latitude: startPoint.latitude + (targetPoint.latitude - startPoint.latitude) * curvedT,
      longitude: startPoint.longitude + (targetPoint.longitude - startPoint.longitude) * curvedT,
    );

    double diff = (targetHeading - startHeading) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    currentHeading = (startHeading + diff * curvedT) % 360.0;
    if (currentHeading < 0) currentHeading += 360.0;
  }
}
