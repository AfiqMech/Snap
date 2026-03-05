import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../viewmodel/snap_view_model.dart';
import '../../../core/models/history_item.dart';
import '../../../features/extraction/extraction_progress.dart'
    as progress_models;
import '../../components/bouncing_button.dart';

class RecentActivitySection extends StatefulWidget {
  final List<HistoryItem> history;

  const RecentActivitySection({super.key, required this.history});

  @override
  State<RecentActivitySection> createState() => _RecentActivitySectionState();
}

class _RecentActivitySectionState extends State<RecentActivitySection> {
  final Set<String> _expandedItemIds = {};
  int _recentCarouselIndex = 0;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SnapViewModel>();
    final state = viewModel.state;
    final colorScheme = Theme.of(context).colorScheme;

    bool hasActive =
        !(state is progress_models.Idle && viewModel.metadata == null);
    bool hasHistory = widget.history.isNotEmpty;

    if (!hasActive && !hasHistory) {
      return _buildEmptyState(colorScheme);
    }

    return Column(
      children: [
        if (hasActive)
          _buildActiveActivityCard(context, viewModel, colorScheme),
        if (hasActive && hasHistory) const SizedBox(height: 24),
        if (hasHistory)
          ...widget.history
              .take(3)
              .map((item) => _buildHistoryTile(context, item)),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.play_circle_outline_rounded,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No recent activity',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveActivityCard(
    BuildContext context,
    SnapViewModel viewModel,
    ColorScheme colorScheme,
  ) {
    final state = viewModel.state;
    final meta = viewModel.metadata;

    String title = "Processing...";
    String status = "Please wait";
    double? progress;
    final List<String> images =
        (meta != null && meta.isPhoto && meta.galleryUrls.isNotEmpty)
        ? meta.galleryUrls.where((url) => url.isNotEmpty).toSet().toList()
        : [meta?.thumbnailUrl ?? ''];

    if (state is progress_models.Analyzing) {
      title = "Analyzing URL...";
      status = state.status;
    } else if (state is progress_models.Downloading) {
      title = meta?.title ?? "Downloading...";
      status = "${state.progress.toStringAsFixed(0)}% • ${state.eta}";
      progress = state.progress / 100;
    } else if (state is progress_models.Success) {
      title = "Download Complete";
      status = "Saved to Gallery";
      progress = 1.0;
    } else if (state is progress_models.Error) {
      title = "Download Failed";
      status = state.message;
      progress = 0.0;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          RepaintBoundary(
            child: _AnimatedThumbnailGlow(
              isProcessing:
                  state is progress_models.Analyzing ||
                  state is progress_models.Downloading,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (images.length > 1)
                      PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (index) {
                          setState(() {
                            _recentCarouselIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return Image.network(
                            images[index],
                            fit: BoxFit.cover,
                          );
                        },
                      )
                    else if (images.isNotEmpty && images[0].isNotEmpty)
                      Image.network(images[0], fit: BoxFit.cover)
                    else
                      Container(color: colorScheme.surfaceContainer),

                    if (images.length > 1)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.black.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            '${_recentCarouselIndex + 1}/${images.length}',
                            style: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),

                    if (meta != null)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.black.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Icon(
                            _getPlatformIcon(meta.platform),
                            size: 20,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),

                    if (meta != null && !meta.isPhoto)
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            if (state is progress_models.Success) {
                              try {
                                final result = await OpenFilex.open(
                                  state.outputPath,
                                );
                                if (result.type != ResultType.done) {
                                  throw result.message;
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Could not open file: ${state.outputPath}',
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              status,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta?.title ?? title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${meta?.author ?? 'Unknown'} • ${_safeFormatSize(viewModel.state)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (progress != null)
            LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          if (state is progress_models.Success)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      icon: Icons.share_rounded,
                      label: 'Share',
                      onTap: () async {
                        final paths = state.savedPaths;
                        await Share.shareXFiles(
                          paths.isNotEmpty
                              ? paths.map((p) => XFile(p)).toList()
                              : [XFile(state.outputPath)],
                          text:
                              'Check out this ${meta?.title ?? 'media'} I snapped!',
                        );
                      },
                      color: colorScheme.secondaryContainer,
                      onColor: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      onTap: () {
                        _showDeleteConfirmation(
                          context,
                          state.outputPath,
                          viewModel,
                        );
                      },
                      color: colorScheme.errorContainer.withValues(alpha: 0.8),
                      onColor: colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required Color onColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: BouncingButton(
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: onColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: onColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTile(BuildContext context, HistoryItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateStr = DateFormat('MMM dd, HH:mm').format(item.timestamp);
    IconData typeIcon;
    switch (item.type) {
      case MediaType.video:
        typeIcon = Icons.movie_rounded;
        break;
      case MediaType.audio:
        typeIcon = Icons.graphic_eq_rounded;
        break;
      case MediaType.image:
        typeIcon = Icons.image_rounded;
        break;
    }

    return GestureDetector(
      onTap: () async {
        if (item.filePath.isNotEmpty) {
          await OpenFilex.open(item.filePath);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 50,
                    height: 50,
                    color: colorScheme.surfaceContainerHighest,
                    child:
                        (item.galleryPaths.isNotEmpty &&
                            item.galleryPaths.length > 1)
                        ? PageView.builder(
                            itemCount: item.galleryPaths.length,
                            itemBuilder: (context, index) {
                              return Image.file(
                                File(item.galleryPaths[index]),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    Icon(typeIcon, color: colorScheme.primary),
                              );
                            },
                          )
                        : item.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                              color: colorScheme.surfaceContainerHighest,
                            ),
                            errorWidget: (_, _, _) =>
                                Icon(typeIcon, color: colorScheme.primary),
                          )
                        : (item.filePath.isNotEmpty &&
                              item.type == MediaType.image)
                        ? Image.file(
                            File(item.filePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Icon(typeIcon, color: colorScheme.primary),
                          )
                        : Icon(typeIcon, color: colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '$dateStr • ${_getPlatformName(item.platform)} • ${_formatFileSize(item.sizeBytes)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.share_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () async {
                    if (item.galleryPaths.isNotEmpty) {
                      await Share.shareXFiles(
                        item.galleryPaths.map((p) => XFile(p)).toList(),
                        text: 'Check out this gallery I snapped!',
                      );
                    } else if (item.filePath.isNotEmpty) {
                      await Share.shareXFiles([
                        XFile(item.filePath),
                      ], text: 'Check out this ${item.title} I snapped!');
                    }
                  },
                ),
                IconButton(
                  icon: AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _expandedItemIds.contains(item.id) ? 0.25 : 0,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: colorScheme.primary,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      if (_expandedItemIds.contains(item.id)) {
                        _expandedItemIds.remove(item.id);
                      } else {
                        _expandedItemIds.add(item.id);
                      }
                    });
                  },
                ),
              ],
            ),
            if (_expandedItemIds.contains(item.id)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Source Link',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.sourceUrl.isNotEmpty
                                ? item.sourceUrl
                                : "Local File",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.sourceUrl.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: item.sourceUrl),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Link copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
            if (item.galleryPaths.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.galleryPaths.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: colorScheme.surfaceContainerHighest,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.file(
                        File(item.galleryPaths[index]),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_rounded, size: 20),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return "${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}";
  }

  String _safeFormatSize(progress_models.ExtractionProgress state) {
    if (state is! progress_models.Success) return "Calculating...";
    final path = state.outputPath;
    if (path.isEmpty) return "0 B";
    int totalBytes = 0;
    try {
      final file = File(path);
      if (file.existsSync()) {
        totalBytes = file.lengthSync();
      } else {
        final dir = Directory(path);
        if (dir.existsSync()) {
          totalBytes = dir.listSync().whereType<File>().fold(
            0,
            (sum, f) => sum + f.lengthSync(),
          );
        }
      }
    } catch (e) {
      debugPrint("Size calculation error: $e");
    }
    return _formatFileSize(totalBytes);
  }

  void _showDeleteConfirmation(
    BuildContext context,
    String path,
    SnapViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File?'),
        content: const Text(
          'This will permanently delete the file from your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              viewModel.reset();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  IconData _getPlatformIcon(String? platform) {
    if (platform == null) return Icons.link_rounded;
    final p = platform.toLowerCase();
    if (p.contains('youtube')) return Icons.play_circle_filled_rounded;
    if (p.contains('instagram')) return Icons.camera_alt_rounded;
    if (p.contains('tiktok')) return Icons.music_note_rounded;
    return Icons.link_rounded;
  }

  String _getPlatformName(String? platform) {
    if (platform == null) return 'Link';
    final p = platform.toLowerCase();
    if (p.contains('youtube')) return 'YouTube';
    if (p.contains('instagram')) return 'Instagram';
    if (p.contains('tiktok')) return 'TikTok';
    return platform;
  }
}

class _AnimatedThumbnailGlow extends StatefulWidget {
  final Widget child;
  final bool isProcessing;

  const _AnimatedThumbnailGlow({
    required this.child,
    required this.isProcessing,
  });

  @override
  State<_AnimatedThumbnailGlow> createState() => _AnimatedThumbnailGlowState();
}

class _AnimatedThumbnailGlowState extends State<_AnimatedThumbnailGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isProcessing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_AnimatedThumbnailGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isProcessing && !oldWidget.isProcessing) {
      _controller.repeat();
    } else if (!widget.isProcessing && oldWidget.isProcessing) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: widget.isProcessing
              ? const EdgeInsets.only(bottom: 3.0)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            gradient: widget.isProcessing
                ? SweepGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.tertiary,
                      colorScheme.primary,
                    ],
                    transform: GradientRotation(
                      _controller.value * 2 * math.pi,
                    ),
                  )
                : null,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
