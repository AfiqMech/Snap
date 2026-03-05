import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'portal_service.dart';

class SettingsService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _dynamicColorKey = 'dynamic_color';
  static const String _oledDarkModeKey = 'oled_dark_mode';

  static const String _wifiOnlyKey = 'wifi_only';
  static const String _backgroundDownloadKey = 'background_download';
  static const String _concurrentDownloadsKey = 'concurrent_downloads';

  static const String _enableNotificationsKey = 'enable_notifications';
  static const String _batterySaverKey = 'battery_saver';

  static const String _autoAnalyzeKey = 'auto_analyze';
  static const String _downloadPathKey = 'download_path';

  static const String _audioQualityKey = 'audio_quality';
  static const String _photoQualityKey = 'photo_quality';
  static const String _privacyModeKey = 'privacy_mode';

  late SharedPreferences _prefs;

  // Defaults
  ThemeMode _themeMode = ThemeMode.system;
  bool _useDynamicColor = true;
  bool _useOledDarkMode = false;

  bool _wifiOnly = false;
  bool _backgroundDownload = true;
  int _concurrentDownloads = 3;

  bool _enableNotifications = true;
  bool _batterySaver = false;

  bool _autoAnalyze = true;
  String _downloadPath = '/Storage/Snap/Downloads'; // Mock default

  String _audioQuality = 'Standard';
  String _photoQuality = 'Optimized';
  bool _privacyMode = false;
  bool _isInstagramLoggedIn = false;

  final _portal = PortalService();

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;
  bool get useOledDarkMode => _useOledDarkMode;

  bool get wifiOnly => _wifiOnly;
  bool get backgroundDownload => _backgroundDownload;
  int get concurrentDownloads => _concurrentDownloads;

  bool get enableNotifications => _enableNotifications;
  bool get batterySaver => _batterySaver;

  bool get autoAnalyze => _autoAnalyze;
  String get downloadPath => _downloadPath;

  String get audioQuality => _audioQuality;
  String get photoQuality => _photoQuality;
  bool get privacyMode => _privacyMode;
  bool get isInstagramLoggedIn => _isInstagramLoggedIn;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Load saved settings or use defaults
    final themeIndex = _prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];
    _useDynamicColor = _prefs.getBool(_dynamicColorKey) ?? true;
    _useOledDarkMode = _prefs.getBool(_oledDarkModeKey) ?? false;

    _wifiOnly = _prefs.getBool(_wifiOnlyKey) ?? false;
    _backgroundDownload = _prefs.getBool(_backgroundDownloadKey) ?? true;
    _concurrentDownloads = _prefs.getInt(_concurrentDownloadsKey) ?? 3;

    _enableNotifications = _prefs.getBool(_enableNotificationsKey) ?? true;
    _batterySaver = _prefs.getBool(_batterySaverKey) ?? false;

    _autoAnalyze = _prefs.getBool(_autoAnalyzeKey) ?? true;
    _downloadPath =
        _prefs.getString(_downloadPathKey) ?? '/Storage/Snap/Downloads';

    _audioQuality = _prefs.getString(_audioQualityKey) ?? 'Standard';
    _photoQuality = _prefs.getString(_photoQualityKey) ?? 'Optimized';
    _privacyMode = _prefs.getBool(_privacyModeKey) ?? false;

    await checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    final ig = await _portal.getCookie('instagram');
    _isInstagramLoggedIn = ig != null && ig.isNotEmpty;
    notifyListeners();
  }

  Future<void> logoutInstagram() async {
    await _portal.removeCookie('instagram');
    _isInstagramLoggedIn = false;
    notifyListeners();
  }

  // Setters
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  Future<void> setDynamicColor(bool value) async {
    _useDynamicColor = value;
    await _prefs.setBool(_dynamicColorKey, value);
    notifyListeners();
  }

  Future<void> setOledDarkMode(bool value) async {
    _useOledDarkMode = value;
    await _prefs.setBool(_oledDarkModeKey, value);
    notifyListeners();
  }

  Future<void> setWifiOnly(bool value) async {
    _wifiOnly = value;
    await _prefs.setBool(_wifiOnlyKey, value);
    notifyListeners();
  }

  Future<void> setBackgroundDownload(bool value) async {
    _backgroundDownload = value;
    await _prefs.setBool(_backgroundDownloadKey, value);
    notifyListeners();
  }

  Future<void> setConcurrentDownloads(int value) async {
    _concurrentDownloads = value;
    await _prefs.setInt(_concurrentDownloadsKey, value);
    notifyListeners();
  }

  Future<void> setEnableNotifications(bool value) async {
    _enableNotifications = value;
    await _prefs.setBool(_enableNotificationsKey, value);
    notifyListeners();
  }

  Future<void> setBatterySaver(bool value) async {
    _batterySaver = value;
    await _prefs.setBool(_batterySaverKey, value);
    notifyListeners();
  }

  Future<void> setAutoAnalyze(bool value) async {
    _autoAnalyze = value;
    await _prefs.setBool(_autoAnalyzeKey, value);
    notifyListeners();
  }

  Future<void> setDownloadPath(String value) async {
    _downloadPath = value;
    await _prefs.setString(_downloadPathKey, value);
    notifyListeners();
  }

  Future<void> setAudioQuality(String value) async {
    _audioQuality = value;
    await _prefs.setString(_audioQualityKey, value);
    notifyListeners();
  }

  Future<void> setPhotoQuality(String value) async {
    _photoQuality = value;
    await _prefs.setString(_photoQualityKey, value);
    notifyListeners();
  }

  Future<void> setPrivacyMode(bool value) async {
    _privacyMode = value;
    await _prefs.setBool(_privacyModeKey, value);
    notifyListeners();
  }
}
