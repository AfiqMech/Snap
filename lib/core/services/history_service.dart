import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';

class HistoryService extends ChangeNotifier {
  static const String _historyKey = 'download_history';
  final SharedPreferences _prefs;
  List<HistoryItem> _items = [];

  HistoryService(this._prefs) {
    _loadHistory();
  }

  List<HistoryItem> get items => List.unmodifiable(_items);

  void _loadHistory() {
    final historyJson = _prefs.getStringList(_historyKey);
    if (historyJson != null) {
      _items =
          historyJson
              .map((item) => HistoryItem.fromJson(jsonDecode(item)))
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    }
  }

  Future<void> addItem(HistoryItem item) async {
    _items.insert(0, item);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> removeItem(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _items.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final historyJson = _items
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    await _prefs.setStringList(_historyKey, historyJson);
  }
}
