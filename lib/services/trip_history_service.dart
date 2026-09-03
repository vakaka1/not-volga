import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_history_item.dart';
import 'ticket_service.dart';

/// Service managing the passenger's trip history with persistent storage across sessions.
class TripHistoryService extends ChangeNotifier {
  static final TripHistoryService instance = TripHistoryService._internal();
  TripHistoryService._internal();

  static const String _keyHistory = 'volga_trip_history_items_v1';

  final List<TripHistoryItem> _items = [];
  bool _isLoaded = false;

  List<TripHistoryItem> get items => List.unmodifiable(_items);
  bool get isLoaded => _isLoaded;

  /// Default baseline mock trips strictly reproducing res/pay-history.webp
  static List<TripHistoryItem> get _defaultMockTrips {
    final now = DateTime.now();
    return [
      TripHistoryItem(
        id: 'mock_today_migalovo_2',
        routeNumber: '2',
        routeTitle: 'Южный - Мигалово',
        startStation: 'Луговая улица',
        fare: 40,
        purchaseTime: DateTime(now.year, now.month, now.day, 7, 48),
        customDateLabel: 'Сегодня',
      ),
      TripHistoryItem(
        id: 'mock_31_aug_mamulino_204',
        routeNumber: '204',
        routeTitle: 'пос. Мамулино - пос. Заволжский',
        startStation: 'Заволжский-2',
        endStation: 'Улица Фрунзе',
        fare: 46,
        purchaseTime: DateTime(now.year, 8, 31, 7, 48),
        customDateLabel: '31 августа',
      ),
      TripHistoryItem(
        id: 'mock_28_aug_centrosvar_30',
        routeNumber: '30',
        routeTitle: 'завод Центросвар - улица Левитана',
        startStation: 'Гимназия №12',
        fare: 40,
        purchaseTime: DateTime(now.year, 8, 28, 16, 30),
        customDateLabel: '28 августа',
      ),
      TripHistoryItem(
        id: 'mock_27_aug_litvinki_208',
        routeNumber: '208',
        routeTitle: 'Автовокзал - Литвинки',
        startStation: 'Автовокзал',
        fare: 40,
        purchaseTime: DateTime(now.year, 8, 27, 17, 49),
        customDateLabel: '27 августа',
      ),
      TripHistoryItem(
        id: 'mock_25_aug_metro_24',
        routeNumber: '24',
        routeTitle: 'ТЦ «Метро» - 1-я за линией',
        startStation: 'Площадь Капошвара',
        fare: 40,
        purchaseTime: DateTime(now.year, 8, 25, 8, 15),
        customDateLabel: '25 августа',
      ),
      TripHistoryItem(
        id: 'mock_22_aug_leroy_33',
        routeNumber: '33',
        routeTitle: 'Мигалово - Гипермаркет Леруа-Мерлен',
        startStation: 'Мигалово',
        fare: 40,
        purchaseTime: DateTime(now.year, 8, 22, 19, 10),
        customDateLabel: '22 августа',
      ),
    ];
  }

  /// Initialize history service and load persisted records.
  Future<void> init({bool force = false}) async {
    if (_isLoaded && !force) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final historyRaw = prefs.getStringList(_keyHistory);

      _items.clear();
      if (historyRaw != null && historyRaw.isNotEmpty) {
        for (final raw in historyRaw) {
          try {
            _items.add(TripHistoryItem.fromJson(raw));
          } catch (e) {
            debugPrint('Error decoding TripHistoryItem: $e');
          }
        }
      }

      // If storage has no items, populate with default history from res/pay-history.webp
      if (_items.isEmpty) {
        _items.addAll(_defaultMockTrips);
        await _save();
      }
    } catch (e) {
      debugPrint('TripHistoryService.init error: $e');
      if (_items.isEmpty) {
        _items.addAll(_defaultMockTrips);
      }
    }

    _isLoaded = true;
    notifyListeners();
  }

  /// Appends a new ticket purchase right at the top of the history.
  Future<void> addTrip(TripHistoryItem item) async {
    // Prevent duplicate entries with same ID
    _items.removeWhere((existing) => existing.id == item.id);
    _items.insert(0, item);
    await _save();
    notifyListeners();
  }

  /// Ensures that an active ticket currently in TicketService is placed at top of history.
  Future<void> ensureTicketInHistory(ActiveTicket activeTicket) async {
    if (_items.any((i) => i.id == activeTicket.id)) {
      return;
    }
    final item = TripHistoryItem(
      id: activeTicket.id,
      routeNumber: activeTicket.routeNumber,
      routeTitle: activeTicket.routeTitle,
      startStation: activeTicket.station,
      endStation: activeTicket.endStation,
      fare: activeTicket.fare,
      purchaseTime: activeTicket.purchaseTime,
    );
    _items.insert(0, item);
    await _save();
    notifyListeners();
  }

  /// Reloads from storage and ensures latest active ticket is present.
  Future<void> reload() async {
    _isLoaded = false;
    await init(force: true);
    if (TicketService.instance.hasActiveTicket) {
      await ensureTicketInHistory(TicketService.instance.activeTicket!);
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _items.map((i) => i.toJson()).toList();
      await prefs.setStringList(_keyHistory, list);
    } catch (e) {
      debugPrint('TripHistoryService._save error: $e');
    }
  }

  @visibleForTesting
  Future<void> clearForTest() async {
    _items.clear();
    _isLoaded = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHistory);
    } catch (_) {}
    notifyListeners();
  }
}
