import 'dart:async';
import 'dart:io';
import 'package:extractor/extractor.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:flutter/foundation.dart';
import '../../core/models/media_metadata.dart';
import '../../core/services/portal_service.dart';

import 'extraction_progress.dart' as progress_models;

class YoutubeDLExtractor {
  final _youtubeDL = YoutubeDLFlutter.instance;
  final _portal = PortalService();
  bool _initialized = false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    final result = await _youtubeDL.initialize(
      enableFFmpeg: true,
      enableAria2c: true,
    );
    _initialized = result.success;
    return _initialized;
  }

  Future<MediaMetadata?> fetchMetadata(String url) async {
    await initialize();
    try {
      final platform = _detectPlatform(url).toLowerCase();
      final cookie = await _portal.getCookie(platform);

      final Map<String, String> options = {};
      if (platform == 'instagram') {
        options['--user-agent'] =
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Mobile/15E148 Safari/604.1';
      }
      if (cookie != null && cookie.isNotEmpty) {
        options['--add-header'] = 'Cookie: $cookie';
      }

      final info = await _youtubeDL.getVideoInfoWithOptions(url, options);

      final bool isPhoto =
          info.ext == 'jpg' ||
          info.ext == 'png' ||
          info.ext == 'webp' ||
          (info.formats?.isEmpty ?? true);

      final List<String> gallery = [];
      if (info.url != null && isPhoto) {
        gallery.add(info.url!);
      }

      final formats =
          info.formats
              ?.map((f) {
                final isVideo = f?.vcodec != "none";
                String? res = f?.resolution;
                if (res == null || res.isEmpty) {
                  if (f?.width != null && f?.height != null) {
                    res = "${f!.width}x${f.height}";
                  }
                }

                int fps = (f?.fps ?? 0).toInt();
                if (fps == 0 && isVideo && f?.formatNote != null) {
                  final match = RegExp(r'(\d+)fps').firstMatch(f!.formatNote!);
                  if (match != null) {
                    fps = int.tryParse(match.group(1)!) ?? 0;
                  }
                }

                String note = f?.formatNote ?? (isVideo ? "Video" : "Audio");
                if (isVideo && fps > 0) {
                  note = "$note • ${fps}fps";
                } else if (!isVideo && f?.tbr != null) {
                  note = "$note • ${(f!.tbr!).toInt()}kbps";
                }

                int size = (f?.filesize ?? 0).toInt();
                if (size <= 0 && f?.tbr != null && info.duration != null) {
                  size = ((f!.tbr! * 1000 * info.duration!) / 8).toInt();
                }

                return MediaFormat(
                  formatId: f?.formatId ?? "",
                  extension: f?.ext ?? "",
                  resolution: res,
                  note: note,
                  sizeBytes: size,
                  isVideo: isVideo,
                );
              })
              .whereType<MediaFormat>()
              .toList() ??
          [];

      if (gallery.isNotEmpty && formats.isEmpty) {
        for (int i = 0; i < gallery.length; i++) {
          formats.add(
            MediaFormat(
              formatId: "photo_$i",
              extension: "jpg",
              isVideo: false,
              note: gallery.length > 1 ? "Image ${i + 1}" : "Highres Original",
              resolution: "Max",
            ),
          );
        }
      }

      // Try to find a higher resolution thumbnail if available
      String? bestThumbnail = info.thumbnail;
      try {
        // Some extractors provide a list of thumbnails in the info object
        // We can check if it exists via dynamic or if the library supports it
        final dynamic dynamicInfo = info;
        if (dynamicInfo.thumbnails != null &&
            dynamicInfo.thumbnails is List &&
            dynamicInfo.thumbnails.isNotEmpty) {
          final List<dynamic> thumbs = dynamicInfo.thumbnails;
          // Sort by resolution (width * height) descending
          thumbs.sort((a, b) {
            final int areaA = (a.width ?? 0) * (a.height ?? 0);
            final int areaB = (b.width ?? 0) * (b.height ?? 0);
            return areaB.compareTo(areaA);
          });
          bestThumbnail = thumbs.first.url ?? bestThumbnail;
        }
      } catch (_) {
        // Fallback to default thumbnail
      }

      return MediaMetadata(
        id: info.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: info.title ?? "Snap Media",
        author: info.uploader ?? "Unknown Creator",
        thumbnailUrl:
            bestThumbnail ?? (gallery.isNotEmpty ? gallery.first : null),
        sourceUrl: url,
        durationSeconds: (info.duration ?? 0).toInt(),
        platform: platform,
        availableFormats: formats,
        isPhoto: isPhoto || gallery.isNotEmpty,
        galleryUrls: gallery,
      );
    } catch (e) {
      return null;
    }
  }

  Stream<progress_models.ExtractionProgress> downloadMedia(
    String url,
    String formatId,
    String outputPath, {
    String? title,
    String audioFormat = 'mp3',
    String audioQuality = 'Standard',
  }) async* {
    yield const progress_models.Analyzing("Configuring Portal...");
    await initialize();

    final isAudio = formatId == 'bestaudio' || formatId.contains('audio');
    final processId = 'snap_${DateTime.now().millisecondsSinceEpoch}';

    final platform = _detectPlatform(url).toLowerCase();
    final cookie = await _portal.getCookie(platform);

    final Map<String, String> customOptions = {
      '--no-check-certificate': '',
      '--no-part': '',
      '--no-continue': '', // Fix for HTTP 416: Requested range not satisfiable
      '--no-cache-dir': '', // Avoid stale session data
      '--restrict-filenames': '',
      '--extractor-args':
          'youtube:player-client=android,ios', // Bypass web-client SABR restrictions
    };

    if (cookie != null && cookie.isNotEmpty) {
      customOptions['--add-header'] = 'Cookie: $cookie';
    }

    final sanitizedTitle = _sanitizeFilename(title ?? "Snap_Media");
    // Get extension for the format
    String ext = isAudio ? "mp3" : "mp4";

    final request = DownloadRequest(
      url: url,
      outputPath: outputPath,
      // Pass the actual expected filename for logging, even if it uses it as a template internally
      outputTemplate: '$sanitizedTitle.$ext',
      format: isAudio ? null : formatId,
      extractAudio: isAudio,
      audioFormat: isAudio ? 'mp3' : null,
      audioQuality: isAudio ? 0 : null,
      processId: processId,
      embedThumbnail: true,
      embedMetadata: true,
      customOptions: customOptions,
    );

    final controller = StreamController<progress_models.ExtractionProgress>();
    final progressSub = _youtubeDL.onProgress
        .where((p) => p.processId == processId)
        .listen((p) {
          final etaStr = p.etaInSeconds > 0
              ? "ETA: ${_formatDuration(Duration(seconds: p.etaInSeconds))}"
              : "Remaining: Calculating...";
          if (!controller.isClosed) {
            controller.add(
              progress_models.Downloading(
                p.progress,
                "Downloading...",
                eta: etaStr,
              ),
            );
          }
        });

    final errorSub = _youtubeDL.onError
        .where((e) => e.processId == processId)
        .listen((e) {
          controller.add(progress_models.Error(e.error));
        });

    // Run the download
    _youtubeDL
        .download(request)
        .then((result) async {
          try {
            if (result.status == OperationStatus.success) {
              // CONSTRUCT INTENDED PATHS
              final finalOutputFileName = "$sanitizedTitle.$ext";
              final finalFullPath = "$outputPath/$finalOutputFileName";
              final literalTemplateName = "%(title)s.%(ext)s";
              final literalPath = "$outputPath/$literalTemplateName";

              debugPrint(
                "Extractor finished. Signal: Success. Result path: ${result.outputPath}",
              );

              // POLLING LOOP: Wait for the file to appear (either sanitized or template)
              bool foundFile = false;
              String actualPath = "";

              for (int i = 0; i < 10; i++) {
                // Try for 2 seconds (10 x 200ms)
                if (await File(finalFullPath).exists()) {
                  foundFile = true;
                  actualPath = finalFullPath;
                  break;
                }
                if (await File(literalPath).exists()) {
                  debugPrint(
                    "Fail-safe: Found literal template file. Renaming to $finalOutputFileName",
                  );
                  try {
                    await File(literalPath).rename(finalFullPath);
                    foundFile = true;
                    actualPath = finalFullPath;
                    break;
                  } catch (e) {
                    debugPrint("Rename failed on attempt $i: $e");
                  }
                }
                // Also check library reported path if it's not a template
                if (result.outputPath != null &&
                    !result.outputPath!.contains('%(') &&
                    await File(result.outputPath!).exists()) {
                  foundFile = true;
                  actualPath = result.outputPath!;
                  break;
                }
                await Future.delayed(const Duration(milliseconds: 200));
              }

              if (foundFile && actualPath.isNotEmpty) {
                debugPrint("File confirmed at: $actualPath");
                await MediaScanner.loadMedia(path: actualPath);
                if (!controller.isClosed) {
                  controller.add(progress_models.Success(actualPath));
                }
              } else {
                debugPrint("Final path resolution failed after polling.");
                if (!controller.isClosed) {
                  controller.add(
                    const progress_models.Error(
                      "Download completed but file was not found or could not be renamed. Please check your Downloads folder.",
                    ),
                  );
                }
              }
            } else if (result.status != OperationStatus.cancelled) {
              if (!controller.isClosed) {
                controller.add(
                  progress_models.Error(
                    result.errorMessage ?? "Download failed",
                  ),
                );
              }
            }
          } catch (e) {
            if (!controller.isClosed) {
              controller.add(
                progress_models.Error("Post-processing error: $e"),
              );
            }
          } finally {
            if (!controller.isClosed) {
              await controller.close();
              // Cleanup subscriptions
              await progressSub.cancel();
              await errorSub.cancel();
            }
          }
        })
        .catchError((e) {
          if (!controller.isClosed) {
            controller.add(progress_models.Error(e.toString()));
            controller.close();
          }
        });

    yield* controller.stream;
  }

  String _sanitizeFilename(String input) {
    String sanitized = input
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_') // Remove invalid chars
        .replaceAll(RegExp(r'\s+'), '_'); // Replace spaces with underscores
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100);
    }
    return sanitized;
  }

  String _detectPlatform(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
      return "youtube";
    }
    if (lowerUrl.contains('instagram.com')) {
      return "instagram";
    }
    if (lowerUrl.contains('tiktok.com')) {
      return "tiktok";
    }
    if (lowerUrl.contains('facebook.com') || lowerUrl.contains('fb.watch')) {
      return "facebook";
    }
    if (lowerUrl.contains('twitter.com') || lowerUrl.contains('x.com')) {
      return "twitter";
    }
    if (lowerUrl.contains('reddit.com')) {
      return "reddit";
    }
    return "social";
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return "${d.inHours}h ${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s";
    }
    if (d.inMinutes > 0) {
      return "${d.inMinutes}m ${d.inSeconds.remainder(60)}s";
    }
    return "${d.inSeconds}s";
  }
}
