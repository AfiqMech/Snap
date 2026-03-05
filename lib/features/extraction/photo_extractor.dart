import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:flutter/foundation.dart';
import 'package:media_scanner/media_scanner.dart';
import '../../core/models/media_metadata.dart';
import '../../core/services/portal_service.dart';

import 'extraction_progress.dart' as progress_models;

class PhotoExtractor {
  final PortalService _portal = PortalService();

  // Unified identity for both login and extraction
  static const String _iphoneUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Mobile/15E148 Safari/604.1';

  Future<Map<String, String>> _getHeaders(String url) async {
    final Map<String, String> headers = {
      'User-Agent': _iphoneUserAgent,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'X-IG-App-ID': '1217981644879628',
      'X-ASBD-ID': '129477',
      'X-Requested-With': 'XMLHttpRequest',
      'Referer': 'https://www.instagram.com/',
    };

    final platform = _detectPlatform(url).toLowerCase();
    final cookie = await _portal.getCookie(platform);
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
      if (cookie.contains('csrftoken=')) {
        final reg = RegExp(r'csrftoken=([^;]+)');
        final match = reg.firstMatch(cookie);
        if (match != null) {
          headers['X-CSRFToken'] = match.group(1)!;
        }
      }
    }

    return headers;
  }

  bool canHandle(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    if (host.contains('youtube.com') &&
        (path.contains('/post/') || path.contains('/community'))) {
      return true;
    }
    if (host.contains('instagram.com')) return true;

    return false;
  }

  Future<MediaMetadata?> fetchMetadata(String url) async {
    try {
      final List<String> gallery = [];
      final headers = await _getHeaders(url);

      // Tier 1: Professional Embed Scrape (Highly resilient for Carousels/Reels)
      if (url.contains('instagram.com/p/') ||
          url.contains('instagram.com/reel/')) {
        final embedUrl =
            "${url.split('?').first.endsWith('/') ? url.split('?').first : '${url.split('?').first}/'}embed/captioned/";
        final embedResult = await _scrapeGenericHtml(
          embedUrl,
          headers,
          gallery,
          isEmbed: true,
        );
        if (embedResult != null && gallery.isNotEmpty) return embedResult;
      }

      // Tier 2: AJAX API
      if (url.contains('instagram.com')) {
        final apiInfo = await _fetchProfessionalIgApi(url, headers, gallery);
        if (apiInfo != null && gallery.isNotEmpty) return apiInfo;
      }

      // Tier 4: Standard Page Scrape
      return await _scrapeGenericHtml(url, headers, gallery);
    } catch (e) {
      debugPrint("PhotoExtractor Error: $e");
      return null;
    }
  }

  Future<MediaMetadata?> _scrapeGenericHtml(
    String url,
    Map<String, String> headers,
    List<String> gallery, {
    bool isEmbed = false,
  }) async {
    final client = http.Client();
    try {
      final response = await client.get(Uri.parse(url), headers: headers);
      if (response.statusCode != 200) return null;

      final body = response.body;
      final document = html.parse(body);

      // Deep Script Excavation
      final scripts = document.querySelectorAll('script');
      final List<String> structuredGallery = [];
      for (final script in scripts) {
        final text = script.text;
        if (text.contains('window._sharedData') ||
            text.contains('window.__additionalData')) {
          _recursiveExtractFromScript(text, structuredGallery);
        }
      }

      if (url.contains('youtube.com')) {
        _extractYoutubeImages(body, gallery);
      } else if (url.contains('instagram.com')) {
        // Only use brute force if structured data failed to find carousel items
        if (structuredGallery.isNotEmpty) {
          gallery.addAll(structuredGallery);
        } else {
          _bruteForceIgDiscovery(body, gallery);
        }
      }

      if (gallery.isEmpty) {
        final ogImg = document
            .querySelector('meta[property="og:image"]')
            ?.attributes['content'];
        if (ogImg != null) gallery.add(ogImg);
      }

      if (gallery.isEmpty) return null;

      // Better deduplication using URL basename/signature if possible
      final uniqueGallery = _deduplicateMediaUrls(gallery);
      String? title =
          document
              .querySelector('meta[property="og:title"]')
              ?.attributes['content'] ??
          document.querySelector('title')?.text;
      title = title?.replaceAll(RegExp(r' • Instagram photos and videos$'), '');

      return _createMetadata(url, title ?? "Snap Post", uniqueGallery);
    } finally {
      client.close();
    }
  }

  Future<MediaMetadata?> _fetchProfessionalIgApi(
    String sourceUrl,
    Map<String, String> headers,
    List<String> gallery,
  ) async {
    try {
      final cleanUrl = sourceUrl.split('?').first;
      final ajaxUrl =
          "${cleanUrl.endsWith('/') ? cleanUrl : '$cleanUrl/'}?__a=1&__d=dis";

      final response = await http.get(Uri.parse(ajaxUrl), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _recursiveExtract(data, gallery);

        if (gallery.isNotEmpty) {
          final uniqueGallery = gallery.toSet().toList();
          return _createMetadata(
            sourceUrl,
            _extractTitleFromJson(data) ?? "Instagram Post",
            uniqueGallery,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  void _bruteForceIgDiscovery(String body, List<String> gallery) {
    // Search for any nested JSON strings
    final jsonMatches = RegExp(r'\{"[^"]+":.*\}').allMatches(body);
    for (final m in jsonMatches) {
      try {
        final data = json.decode(m.group(0)!);
        _recursiveExtract(data, gallery);
      } catch (_) {}
    }

    // Direct High-Res Scan (Images + Videos)
    final bruteRegex = RegExp(
      r'https?://scontent[^"'
      r'\s]+\.(?:jpg|png|webp|heic|mp4)[^"'
      r'\s]*',
    );
    for (final m in bruteRegex.allMatches(body)) {
      final u = m.group(0)?.replaceAll(r'\u002F', '/');
      if (u != null &&
          (u.contains('/v/') ||
              u.contains('/p/') ||
              u.contains('1080x1080') ||
              u.contains('.mp4') ||
              u.contains('_n.jpg'))) {
        if (!gallery.contains(u)) gallery.add(u);
      }
    }
  }

  String? _extractTitleFromJson(dynamic data) {
    try {
      final media = data['items']?[0] ?? data['graphql']?['shortcode_media'];
      return media?['caption']?['text'] ??
          media?['edge_media_to_caption']?['edges']?[0]?['node']?['text'];
    } catch (_) {
      return null;
    }
  }

  MediaMetadata _createMetadata(
    String url,
    String title,
    List<String> gallery,
  ) {
    return MediaMetadata(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      author: _detectPlatform(url),
      thumbnailUrl: gallery.first,
      sourceUrl: url,
      platform: _detectPlatform(url),
      isPhoto: true,
      galleryUrls: gallery,
      availableFormats:
          gallery.asMap().entries.map((entry) {
            final index = entry.key;
            final itemUrl = entry.value;
            final isVideo = itemUrl.contains('.mp4');
            return MediaFormat(
              formatId: "photo_$index",
              extension: isVideo ? "mp4" : "jpg",
              isVideo: isVideo,
              note: gallery.length > 1
                  ? "Snap Item ${index + 1} (${isVideo ? 'Video' : 'Photo'})"
                  : (isVideo ? "High Quality Video" : "Highres Photo"),
              resolution: "Max",
              thumbnailUrl: isVideo ? gallery.first : itemUrl,
            );
          }).toList()..insert(
            0,
            MediaFormat(
              formatId: "photo_best",
              extension: gallery.any((u) => u.contains('.mp4')) ? "mp4" : "jpg",
              isVideo: gallery.any((u) => u.contains('.mp4')),
              note: gallery.length > 1
                  ? "Snap Entire Collection (${gallery.length} items)"
                  : "Standard Quality",
              resolution: "Peak",
              thumbnailUrl: gallery.first,
            ),
          ),
    );
  }

  void _extractYoutubeImages(String body, List<String> gallery) {
    final ytPatterns = [
      RegExp(r'https://[a-z0-9]+\.ggpht\.com/([a-zA-Z0-9_\-]+)'),
      RegExp(r'https://[a-z0-9]+\.googleusercontent\.com/([a-zA-Z0-9_\-]+)'),
    ];
    for (final pattern in ytPatterns) {
      for (final m in pattern.allMatches(body)) {
        final id = m.group(1);
        if (id != null && id.length > 20) {
          final baseUrl = pattern.pattern.contains('ggpht')
              ? "https://yt3.ggpht.com"
              : "https://lh3.googleusercontent.com";
          final fullUrl = "$baseUrl/$id=s0";
          if (!gallery.contains(fullUrl)) gallery.add(fullUrl);
        }
      }
    }
  }

  void _recursiveExtractFromScript(String script, List<String> gallery) {
    try {
      final jsonMatches = RegExp(r'\{"[^"]+":.*\}').allMatches(script);
      for (final m in jsonMatches) {
        try {
          final data = json.decode(m.group(0)!);
          _recursiveExtract(data, gallery);
        } catch (_) {}
      }
    } catch (_) {}
  }

  List<String> _deduplicateMediaUrls(List<String> urls) {
    final Map<String, String> uniqueMap = {};
    for (final url in urls) {
      if (url.isEmpty) continue;
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          final filename = pathSegments.last;
          if (!uniqueMap.containsKey(filename)) {
            uniqueMap[filename] = url;
          }
        } else {
          uniqueMap[url] = url;
        }
      } else {
        uniqueMap[url] = url;
      }
    }
    return uniqueMap.values.toSet().toList();
  }

  void _recursiveExtract(dynamic data, List<String> gallery) {
    if (data is Map) {
      if (data.containsKey('edge_sidecar_to_children')) {
        final edges = data['edge_sidecar_to_children']?['edges'];
        if (edges is List) {
          for (final edge in edges) {
            final url = edge['node']?['display_url'];
            if (url != null && !gallery.contains(url)) gallery.add(url);
          }
        }
      }
      if (data.containsKey('carousel_media')) {
        final items = data['carousel_media'];
        if (items is List) {
          for (final item in items) {
            final url = item['image_versions2']?['candidates']?[0]?['url'];
            if (url != null && !gallery.contains(url)) gallery.add(url);
          }
        }
      }
      if (data.containsKey('video_url')) {
        final String? url = data['video_url'];
        if (url != null && !gallery.contains(url)) gallery.add(url);
      }
      if (data.containsKey('video_versions')) {
        final items = data['video_versions'];
        if (items is List && items.isNotEmpty) {
          final url = items[0]?['url'];
          if (url != null && !gallery.contains(url)) gallery.add(url);
        }
      }
      if (data.containsKey('display_url')) {
        final String? url = data['display_url'];
        if (url != null && !gallery.contains(url)) gallery.add(url);
      }
      data.forEach((key, value) {
        if (value != null && (value is Map || value is List)) {
          _recursiveExtract(value, gallery);
        }
      });
    } else if (data is List) {
      for (final item in data) {
        if (item != null) _recursiveExtract(item, gallery);
      }
    }
  }

  Stream<progress_models.ExtractionProgress> downloadPhotos(
    List<String> urls,
    String outputPath, {
    String quality = 'Original',
    bool privacyMode = false,
  }) async* {
    yield const progress_models.Analyzing("Preparing Snap...");
    final List<String> savedPaths = [];
    try {
      final headers = await _getHeaders(urls.first);
      int count = 0;
      for (final url in urls) {
        count++;
        yield progress_models.Downloading(
          (count / urls.length) * 100,
          "Snapping item $count of ${urls.length}...",
        );
        try {
          final response = await http.get(Uri.parse(url), headers: headers);
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            final String ext = url.contains('.mp4')
                ? 'mp4'
                : (url.contains('.png')
                      ? 'png'
                      : (url.contains('.webp') ? 'webp' : 'jpg'));
            final String fileName =
                'Snap_${DateTime.now().millisecondsSinceEpoch}_$count.$ext';
            final File file = File('$outputPath/$fileName');
            await file.writeAsBytes(response.bodyBytes);
            savedPaths.add(file.path);
            try {
              await MediaScanner.loadMedia(path: file.path);
            } catch (_) {}
          }
        } catch (_) {}
      }
      if (savedPaths.isNotEmpty) {
        yield progress_models.Success(
          savedPaths.length == 1 ? savedPaths.first : outputPath,
          savedPaths: savedPaths,
        );
      } else {
        yield progress_models.Error("No photos were successfully snapped.");
      }
    } catch (e) {
      yield progress_models.Error("Extraction crashed: $e");
    }
  }

  String _detectPlatform(String url) {
    if (url.contains('youtube.com')) return "YouTube";
    if (url.contains('instagram.com')) return "Instagram";
    return "Social";
  }
}
