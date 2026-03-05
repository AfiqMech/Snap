import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/services/portal_service.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class PortalLoginScreen extends StatefulWidget {
  final String platform;
  final String loginUrl;
  final bool clearSession;

  const PortalLoginScreen({
    super.key,
    required this.platform,
    required this.loginUrl,
    this.clearSession = false,
  });

  @override
  State<PortalLoginScreen> createState() => _PortalLoginScreenState();
}

class _PortalLoginScreenState extends State<PortalLoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isCapturing = false;
  Timer? _cookieTimer;

  // Consistent User-Agent for both login and extraction
  static const String _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Mobile/15E148 Safari/604.1';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_userAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            _autoCapture(url);
          },
          onUrlChange: (change) {
            if (change.url != null) {
              _autoCapture(change.url!);
            }
          },
        ),
      );

    _initialLoad();

    // Periodically check for cookies as a fail-safe
    _cookieTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!_isCapturing) {
        _checkCookiesIndependently();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _cookieTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    if (widget.clearSession) {
      await WebViewCookieManager().clearCookies();
      await _controller.clearCache();
      await _controller.clearLocalStorage();
    }
    await _controller.loadRequest(Uri.parse(widget.loginUrl));
  }

  Future<void> _checkCookiesIndependently() async {
    try {
      final String url = await _controller.currentUrl() ?? "";
      if (url.isEmpty || url == "about:blank") return;
      await _autoCapture(url);
    } catch (_) {}
  }

  Future<void> _autoCapture(String url) async {
    if (_isCapturing) return;

    // Expanded Success States (include Save Info, Stories, and Direct)
    final bool loggedIn =
        (widget.platform == 'instagram' &&
        (url.contains('instagram.com/reels/') ||
            url.contains('instagram.com/p/') ||
            url.contains('instagram.com/direct/') ||
            url.contains('instagram.com/explore/') ||
            url.contains('instagram.com/stories/') ||
            url.contains('accounts/onetap') || // "Save Your Login Info" page
            url == 'https://www.instagram.com/' ||
            url.startsWith('https://www.instagram.com/?')));

    // If we've definitely left the login/signup wall
    final bool movedFarFromLogin =
        !url.contains('login') &&
        !url.contains('signup') &&
        !url.contains('emailsignup') &&
        url.length > 25; // Simple check for non-trivial paths

    if (loggedIn || movedFarFromLogin) {
      await _captureSession();
    }
  }

  Future<void> _captureSession() async {
    if (_isCapturing || !mounted) return;

    try {
      final Object result = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      if (!mounted) return;

      String cookieStr = result.toString();
      if (cookieStr.startsWith('"') && cookieStr.endsWith('"')) {
        cookieStr = cookieStr.substring(1, cookieStr.length - 1);
      }

      // Deep Cookie Scan: sessionid (IG), sid_guard/msid (TikTok), ds_user_id (IG Login Check)
      final bool hasSession =
          cookieStr.contains('sessionid') ||
          cookieStr.contains('sid_guard') ||
          cookieStr.contains('msid') ||
          cookieStr.contains('ds_user_id') ||
          cookieStr.contains('auth_token');

      if (cookieStr.isNotEmpty && cookieStr != "null" && hasSession) {
        _isCapturing = true;
        _cookieTimer?.cancel();

        final portal = context.read<PortalService>();
        await portal.saveCookie(widget.platform, cookieStr);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sign In Successful: ${widget.platform.toUpperCase()}',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint("Auth Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Sign in to ${widget.platform[0].toUpperCase()}${widget.platform.substring(1)}',
        ),
        backgroundColor: const Color(0xFF1E1E2C),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            ),
        ],
      ),
    );
  }
}
