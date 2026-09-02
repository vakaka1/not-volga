import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BalanceService extends ChangeNotifier {
  static final BalanceService instance = BalanceService._internal();
  BalanceService._internal();

  static const String _balanceKey = 'app_user_balance';
  int _balance = 0;
  bool _isLoaded = false;

  int get balance => _balance;
  bool get isLoaded => _isLoaded;

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _balance = prefs.getInt(_balanceKey) ?? 0;
    } catch (_) {
      _balance = 0;
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> addBalance(int amount) async {
    if (amount <= 0) return;
    _balance += amount;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_balanceKey, _balance);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setBalance(int amount) async {
    _balance = amount;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_balanceKey, _balance);
    } catch (_) {}
    notifyListeners();
  }
}
