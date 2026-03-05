import 'package:shared_preferences/shared_preferences.dart';

class PortalService {
  static const String _prefix = "portal_key_";

  Future<void> saveCookie(String platform, String cookie) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("$_prefix$platform", cookie);
  }

  Future<String?> getCookie(String platform) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("$_prefix$platform");
  }

  Future<void> removeCookie(String platform) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("$_prefix$platform");
  }
}
