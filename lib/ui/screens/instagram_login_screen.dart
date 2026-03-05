import 'package:flutter/material.dart';
import 'dart:async';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/services/portal_service.dart';
import '../../core/services/settings_service.dart';

class InstagramLoginScreen extends StatefulWidget {
  const InstagramLoginScreen({super.key});

  @override
  State<InstagramLoginScreen> createState() => _InstagramLoginScreenState();
}

class _InstagramLoginScreenState extends State<InstagramLoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  Timer? _cookieCheckTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
            });
            _checkCookies(url);
          },
          onUrlChange: (UrlChange change) {
            if (change.url != null) {
              _checkCookies(change.url!);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.instagram.com/accounts/login/'));

    // Periodic check every 2 seconds to catch logins that happen without a full page reload or late navigations
    _cookieCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkCookies('');
    });
  }

  @override
  void dispose() {
    _cookieCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkCookies(String url) async {
    try {
      // 1. URL Path Detection (The most reliable "success" trigger)
      // If we are no longer on the login/signup pages and on the main feed/profile, it's a success.
      final uri = Uri.tryParse(url);
      if (uri != null &&
          uri.host.contains('instagram.com') &&
          !url.contains('/accounts/login') &&
          !url.contains('/accounts/signup') &&
          url.length > 25) {
        // Ensure it's not just a partial load

        final String cookies =
            await _controller.runJavaScriptReturningResult('document.cookie')
                as String;
        final cleanCookies = cookies.replaceAll('"', '');

        // Even if sessionid is HttpOnly, we catch the redirect.
        // We save whatever we can see (ds_user_id, csrftoken etc help yt-dlp)
        _finalizeLogin(cleanCookies);
        return;
      }

      // 2. JS Cookie Detection (Fallback for background logins)
      final String cookies =
          await _controller.runJavaScriptReturningResult('document.cookie')
              as String;
      final cleanCookies = cookies.replaceAll('"', '');

      if (cleanCookies.contains('sessionid=') ||
          cleanCookies.contains('ds_user_id=') ||
          cleanCookies.contains('csrftoken=')) {
        _finalizeLogin(cleanCookies);
      }
    } catch (e) {
      // Ignore JS errors
    }
  }

  Future<void> _finalizeLogin(String cookies) async {
    if (_cookieCheckTimer == null) return; // Already finalized

    _cookieCheckTimer?.cancel();
    _cookieCheckTimer = null;

    final PortalService portalService = PortalService();
    await portalService.saveCookie('instagram', cookies);

    if (mounted) {
      // Notify settings service
      context.read<SettingsService>().checkLoginStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instagram Authenticated Successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Instagram Login',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: colorScheme.surface,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
