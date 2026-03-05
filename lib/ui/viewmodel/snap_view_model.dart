import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/models/media_metadata.dart';
import '../../features/extraction/youtube_dl_extractor.dart';
import '../../features/extraction/photo_extractor.dart';
import '../../features/extraction/extraction_progress.dart' as progress_models;
import '../../core/services/settings_service.dart';
import '../../core/services/history_service.dart';
import '../../core/models/history_item.dart';
import '../../core/services/notification_service.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class SnapViewModel extends ChangeNotifier {
  final YoutubeDLExtractor _videoExtractor;
  final PhotoExtractor _photoExtractor;
  final HistoryService _historyService;
  final NotificationService _notificationService;

  progress_models.ExtractionProgress _state = const progress_models.Idle();
  progress_models.ExtractionProgress get state => _state;

  MediaMetadata? _metadata;
  MediaMetadata? get metadata => _metadata;

  bool _hasShownConfigSheet = false;
  bool get hasShownConfigSheet => _hasShownConfigSheet;

  SnapViewModel(
    this._videoExtractor,
    this._photoExtractor,
    this._historyService,
    this._notificationService,
  );

  void reset() {
    _state = const progress_models.Idle();
    _metadata = null;
    _hasShownConfigSheet = false;
    notifyListeners();
  }

  void markConfigSheetShown() {
    _hasShownConfigSheet = true;
    notifyListeners();
  }

  Future<void> analyzeUrl(String url) async {
    if (url.trim().isEmpty) return;

    _state = const progress_models.Analyzing("Analyzing link...");
    _hasShownConfigSheet = false;
    notifyListeners();

    try {
      MediaMetadata? info;

      // Phase 1: Try Photo Extractor first for static links
      if (_photoExtractor.canHandle(url)) {
        info = await _photoExtractor.fetchMetadata(url);
      }

      // Phase 2: Fallback to Video Extractor
      info ??= await _videoExtractor.fetchMetadata(url);

      if (info != null) {
        _metadata = info;
        _state = const progress_models.Idle();
      } else {
        _state = const progress_models.Error(
          "Could not find any media at that link.",
        );
      }
    } catch (e) {
      _state = progress_models.Error(e.toString());
    } finally {
      notifyListeners();
    }
  }

  Future<void> startDownload(
    MediaMetadata metadata,
    String formatId,
    String outputPath,
    SettingsService settings,
  ) async {
    const int notificationId = 1001;

    _state = const progress_models.Analyzing("Preparing download...");
    notifyListeners();

    if (settings.enableNotifications) {
      await _notificationService.showProgressNotification(
        id: notificationId,
        title: "Snap",
        body: "Preparing: ${metadata.title}",
        progress: 0,
        maxProgress: 100,
        indeterminate: true,
      );
    }

    try {
      late Stream<progress_models.ExtractionProgress> stream;
      if (metadata.isPhoto) {
        if (formatId == "photo_best") {
          stream = _photoExtractor.downloadPhotos(
            metadata.galleryUrls,
            outputPath,
            quality: settings.photoQuality,
            privacyMode: settings.privacyMode,
          );
        } else {
          final index = int.tryParse(formatId.replaceFirst("photo_", "")) ?? 0;
          stream = _photoExtractor.downloadPhotos(
            [metadata.galleryUrls[index]],
            outputPath,
            quality: settings.photoQuality,
            privacyMode: settings.privacyMode,
          );
        }
      } else {
        stream = _videoExtractor.downloadMedia(
          metadata.sourceUrl,
          formatId,
          outputPath,
          title: metadata.title,
          audioFormat: 'best',
          audioQuality: settings.audioQuality,
        );
      }

      await for (final progress in stream) {
        _state = progress;
        notifyListeners();

        if (settings.enableNotifications) {
          if (progress is progress_models.Downloading) {
            await _notificationService.showProgressNotification(
              id: notificationId,
              title: "Downloading: ${metadata.title}",
              body:
                  "${progress.progress.toStringAsFixed(1)}% - ${progress.status}",
              progress: progress.progress.toInt(),
              maxProgress: 100,
            );
          } else if (progress is progress_models.Success) {
            await _notificationService.showSuccessNotification(
              id: notificationId,
              title: "Download Complete",
              body: metadata.title,
            );
          } else if (progress is progress_models.Error) {
            await _notificationService.showErrorNotification(
              id: notificationId,
              title: "Download Failed",
              body: progress.message,
            );
          }
        }

        if (progress is progress_models.Success) {
          final path = progress.outputPath;
          int finalSize = 0;
          try {
            final file = File(path);
            if (file.existsSync()) {
              finalSize = file.lengthSync();
            } else {
              final dir = Directory(path);
              if (dir.existsSync()) {
                finalSize = dir.listSync().whereType<File>().fold(
                  0,
                  (sum, f) => sum + f.lengthSync(),
                );
              }
            }
          } catch (e) {
            debugPrint("Size calculation error: $e");
          }

          await _historyService.addItem(
            HistoryItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: metadata.title,
              thumbnailUrl: metadata.thumbnailUrl ?? "",
              sourceUrl: metadata.sourceUrl,
              filePath: path,
              timestamp: DateTime.now(),
              type: metadata.isPhoto ? MediaType.image : MediaType.video,
              platform: metadata.platform,
              sizeBytes: finalSize,
              galleryPaths: metadata.isPhoto ? [path] : [],
            ),
          );
        }
      }
    } catch (e) {
      _state = progress_models.Error(e.toString());
      if (settings.enableNotifications) {
        await _notificationService.showErrorNotification(
          id: notificationId,
          title: "Download Error",
          body: e.toString(),
        );
      }
      notifyListeners();
    }
  }

  // Restore Toolkit Methods
  Future<void> compressLocalVideo({
    required String filePath,
    required VideoQuality quality,
    required bool muteAudio,
    required String format,
    required String fileName,
  }) async {
    _state = const progress_models.Analyzing("Compressing video...");
    notifyListeners();

    try {
      final mediaInfo = await VideoCompress.compressVideo(
        filePath,
        quality: quality,
        deleteOrigin: false,
        includeAudio: !muteAudio,
      );

      if (mediaInfo != null && mediaInfo.path != null) {
        final compressedFile = File(mediaInfo.path!);
        final ext = p.extension(filePath);
        final directory = p.dirname(filePath);
        final newPath = p.join(directory, "${fileName}_compressed$ext");

        await compressedFile.copy(newPath);
        _state = progress_models.Success(newPath);

        await _historyService.addItem(
          HistoryItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: "Compressed: $fileName",
            thumbnailUrl: "",
            sourceUrl: "local",
            filePath: newPath,
            timestamp: DateTime.now(),
            type: MediaType.video,
            platform: "local",
            sizeBytes: compressedFile.lengthSync(),
            galleryPaths: [],
          ),
        );
      } else {
        _state = const progress_models.Error(
          "Compression failed or was cancelled.",
        );
      }
    } catch (e) {
      _state = progress_models.Error(e.toString());
    } finally {
      notifyListeners();
    }
  }

  Future<void> compressLocalImages({
    required List<String> filePaths,
    required List<String> fileNames,
    required int quality,
    required bool limitTo1MB,
    required String format,
    required bool removeMetadata,
  }) async {
    _state = const progress_models.Analyzing("Compressing images...");
    notifyListeners();

    try {
      final List<String> savedPaths = [];
      final directory = p.dirname(filePaths.first);

      for (int i = 0; i < filePaths.length; i++) {
        final path = filePaths[i];
        final name = fileNames[i];
        final ext = p.extension(path);
        final targetPath = p.join(directory, "${name}_optimized$ext");

        final result = await FlutterImageCompress.compressAndGetFile(
          path,
          targetPath,
          quality: quality,
          keepExif: !removeMetadata,
          format: format == "png" ? CompressFormat.png : CompressFormat.jpeg,
        );

        if (result != null) {
          savedPaths.add(result.path);
        }
      }

      if (savedPaths.isNotEmpty) {
        _state = progress_models.Success(
          savedPaths.first,
          savedPaths: savedPaths,
        );

        await _historyService.addItem(
          HistoryItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: "Optimized: ${fileNames.length} images",
            thumbnailUrl: "",
            sourceUrl: "local",
            filePath: savedPaths.first,
            timestamp: DateTime.now(),
            type: MediaType.image,
            platform: "local",
            sizeBytes: File(savedPaths.first).lengthSync(),
            galleryPaths: savedPaths,
          ),
        );
      } else {
        _state = const progress_models.Error("Image optimization failed.");
      }
    } catch (e) {
      _state = progress_models.Error(e.toString());
    } finally {
      notifyListeners();
    }
  }
}
