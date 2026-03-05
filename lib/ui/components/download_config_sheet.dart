import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/models/media_metadata.dart';
import '../viewmodel/snap_view_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DownloadConfigSheet extends StatefulWidget {
  final MediaMetadata? metadata;
  final Function(String formatId) onStartDownload;
  final Function(DragUpdateDetails)? onDragUpdate;
  final Function(DragEndDetails)? onDragEnd;
  final bool isQuickMode;

  const DownloadConfigSheet({
    super.key,
    this.metadata,
    required this.onStartDownload,
    this.onDragUpdate,
    this.onDragEnd,
    this.isQuickMode = false,
  });

  static Future<dynamic> show(
    BuildContext context,
    MediaMetadata? metadata,
    Function(String) onStartDownload, {
    bool isQuickMode = false,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.1),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Consumer<SnapViewModel>(
          builder: (context, viewModel, child) {
            return _GradualBlurDialog(
              metadata: viewModel.metadata,
              onStartDownload: onStartDownload,
              isQuickMode: isQuickMode,
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Smooth slide-up from bottom
        return SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: child,
        );
      },
    );
  }

  @override
  State<DownloadConfigSheet> createState() => _DownloadConfigSheetState();
}

class _GradualBlurDialog extends StatefulWidget {
  final MediaMetadata? metadata;
  final Function(String) onStartDownload;
  final bool isQuickMode;

  const _GradualBlurDialog({
    required this.metadata,
    required this.onStartDownload,
    this.isQuickMode = false,
  });

  @override
  State<_GradualBlurDialog> createState() => _GradualBlurDialogState();
}

class _GradualBlurDialogState extends State<_GradualBlurDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _dragController;

  @override
  void initState() {
    super.initState();
    _dragController = AnimationController(
      vsync: this,
      value: 0.0,
      upperBound: 2000.0, // Arbitrarily large to allow dragging down freely
    );
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(color: Colors.transparent),
        ),
        AnimatedBuilder(
          animation: _dragController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _dragController.value),
              child: child,
            );
          },
          child: Align(
            alignment: Alignment.bottomCenter,
            child: DownloadConfigSheet(
              metadata: widget.metadata,
              onStartDownload: widget.onStartDownload,
              isQuickMode: widget.isQuickMode,
              onDragUpdate: (details) {
                double newValue = _dragController.value + details.delta.dy;
                if (newValue < 0) newValue = 0;
                _dragController.value = newValue;
              },
              onDragEnd: (details) {
                if (_dragController.value > 150 ||
                    (details.primaryVelocity ?? 0) > 500) {
                  Navigator.pop(context);
                } else {
                  _dragController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DownloadConfigSheetState extends State<DownloadConfigSheet> {
  String _selectedType = 'video';
  String _selectedFormat = 'auto';
  final String _selectedQuality = 'best';
  final Set<String> _selectedAdditional = {};

  // Video Specific In-depth states
  String _activeVideoPreference = 'quality';
  String _selectedCodec = 'h264';
  String _selectedResolution = '1080p';
  String _selectedVideoAudioFormat = 'm4a';
  String _selectedVideoAudioBitrate = '128k';

  // Audio Specific In-depth states
  String _activeAudioPreference = 'format';
  String _selectedAudioCodec = 'm4a';
  String _selectedAudioBitrate = '256k';
  final Set<String> _selectedAudioAdvanced = {};

  // Image Specific In-depth states
  String _activeImagePreference = 'format';
  String _selectedImageCodec = 'original';
  String _selectedImageQuality = 'original';
  final Set<String> _selectedImageAdvanced = {};

  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Image Batch Selection
  final List<bool> _selectedImages = [];
  bool _selectAll = true;

  final ScrollController _scrollController = ScrollController();
  bool _isAtTop = true;

  void _syncMetadata() {
    if (widget.metadata != null) {
      final meta = widget.metadata!;

      // Sync selection images list
      final Set<String> uniqueGalleryRows = meta.galleryUrls
          .where((url) => url.isNotEmpty)
          .toSet();
      final galleryCount = uniqueGalleryRows.length;

      _selectedImages.clear();
      if (galleryCount > 0) {
        _selectedImages.addAll(List.generate(galleryCount, (index) => true));
      } else if (meta.thumbnailUrl != null) {
        _selectedImages.addAll([true]);
      } else {
        _selectedImages.add(true);
      }
      _selectAll = true;

      // Sync type
      if (meta.isPhoto) {
        _selectedType = 'image';
      } else {
        _selectedType = meta.availableFormats.any((f) => f.isVideo)
            ? 'video'
            : 'audio';
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset <= 0) {
        if (!_isAtTop) setState(() => _isAtTop = true);
      } else {
        if (_isAtTop) setState(() => _isAtTop = false);
      }
    });
    _syncMetadata();
  }

  @override
  void didUpdateWidget(DownloadConfigSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.metadata != oldWidget.metadata) {
      setState(() {
        _syncMetadata();
        _currentPage = 0;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onVerticalDragUpdate: widget.onDragUpdate,
                onVerticalDragEnd: widget.onDragEnd,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Configuration',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.6,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isQuickMode)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: OutlinedButton.icon(
                              onPressed: widget.metadata == null
                                  ? null
                                  : () {
                                      Navigator.pop(context, 'open_full');
                                    },
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 14,
                              ),
                              label: const Text('Open Snap'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                shape: const StadiumBorder(),
                                visualDensity: VisualDensity.compact,
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        IconButton(
                          onPressed: () {},
                          icon: Icon(
                            Icons.info_outline_rounded,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Flexible(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // Only allow parent swipe-to-dismiss when we are at the top
                    // This listener is primarily to prevent the parent from dismissing
                    // when the child scroll view is being scrolled.
                    // The _isAtTop check in GestureDetector handles the actual drag.
                    return false; // Do not block the notification from bubbling up
                  },
                  child: GestureDetector(
                    onVerticalDragUpdate: _isAtTop ? widget.onDragUpdate : null,
                    onVerticalDragEnd: _isAtTop ? widget.onDragEnd : null,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.metadata != null) ...[
                            _buildPreviewSection(context),
                            const SizedBox(height: 24),
                          ],
                          _buildSectionHeader(context, 'TYPE'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _PillToggle(
                                  title: 'Video',
                                  icon: Icons.movie_rounded,
                                  isSelected: _selectedType == 'video',
                                  onTap: () =>
                                      setState(() => _selectedType = 'video'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PillToggle(
                                  title: 'Audio',
                                  icon: Icons.audio_file_rounded,
                                  isSelected: _selectedType == 'audio',
                                  onTap: () =>
                                      setState(() => _selectedType = 'audio'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PillToggle(
                                  title: 'Image',
                                  icon: Icons.image_rounded,
                                  isSelected: _selectedType == 'image',
                                  onTap: () =>
                                      setState(() => _selectedType = 'image'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildSectionHeader(context, 'FORMAT'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _SmallPillToggle(
                                title: 'Auto',
                                isSelected: _selectedFormat == 'auto',
                                onTap: () =>
                                    setState(() => _selectedFormat = 'auto'),
                              ),
                              const SizedBox(width: 8),
                              _SmallPillToggle(
                                title: 'Custom',
                                isSelected: _selectedFormat == 'custom',
                                onTap: () =>
                                    setState(() => _selectedFormat = 'custom'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(context, 'PREFERENCE'),
                              const SizedBox(height: 12),
                              _buildPreferenceSection(context),
                              const SizedBox(height: 24),
                              _buildSectionHeader(context, 'ADDITIONAL'),
                              const SizedBox(height: 12),
                              _buildAdditionalSection(context),
                            ],
                          ),
                          const SizedBox(height: 120), // Extra scrollable area
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    flex: 3, // 30% width
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (widget.isQuickMode) {
                          SystemNavigator.pop();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        padding: EdgeInsets.zero,
                        shape: const StadiumBorder(),
                        side: BorderSide(color: colorScheme.outlineVariant),
                        backgroundColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                      ),
                      child: Text(
                        widget.isQuickMode ? 'Exit' : 'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 7, // 70% width
                    child: FilledButton.icon(
                      onPressed: widget.metadata == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              final actualFormatId = _selectedType == 'image'
                                  ? "photo_best"
                                  : _selectedQuality;
                              widget.onStartDownload(actualFormatId);

                              if (widget.isQuickMode) {
                                Future.delayed(
                                  const Duration(milliseconds: 500),
                                  () {
                                    SystemNavigator.pop();
                                  },
                                );
                              }
                            },
                      icon: const Icon(Icons.download_rounded),
                      label: Text(
                        _getDownloadButtonText(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.1,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: const StadiumBorder(),
                        elevation: widget.metadata == null ? 0 : 4,
                        shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferenceSection(BuildContext context) {
    final bool isEnabled = _selectedFormat == 'custom';

    if (_selectedType == 'video') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _IconChip(
                  title: 'Quality',
                  icon: Icons.high_quality_rounded,
                  isSelected: _activeVideoPreference == 'quality',
                  isEnabled: isEnabled,
                  onTap: () =>
                      setState(() => _activeVideoPreference = 'quality'),
                ),
                const SizedBox(width: 8),
                _IconChip(
                  title: 'Resolution',
                  icon: Icons.aspect_ratio_rounded,
                  isSelected: _activeVideoPreference == 'resolution',
                  isEnabled: isEnabled,
                  onTap: () =>
                      setState(() => _activeVideoPreference = 'resolution'),
                ),
                const SizedBox(width: 8),
                _IconChip(
                  title: 'Audio Format',
                  icon: Icons.audio_file_rounded,
                  isSelected: _activeVideoPreference == 'audio',
                  isEnabled: isEnabled,
                  onTap: () => setState(() => _activeVideoPreference = 'audio'),
                ),
              ],
            ),
          ),
          if (isEnabled) ...[
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(children: _buildVideoSubOptions(context)),
            ),
          ],
        ],
      );
    } else if (_selectedType == 'audio') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _IconChip(
                  title: 'Format',
                  icon: Icons.audio_file_rounded,
                  isSelected: _activeAudioPreference == 'format',
                  isEnabled: isEnabled,
                  onTap: () =>
                      setState(() => _activeAudioPreference = 'format'),
                ),
                const SizedBox(width: 8),
                _IconChip(
                  title: 'Quality',
                  icon: Icons.high_quality_rounded,
                  isSelected: _activeAudioPreference == 'quality',
                  isEnabled: isEnabled,
                  onTap: () =>
                      setState(() => _activeAudioPreference = 'quality'),
                ),
                const SizedBox(width: 8),
                _IconChip(
                  title: 'Advanced',
                  icon: Icons.settings_suggest_rounded,
                  isSelected: _activeAudioPreference == 'advanced',
                  isEnabled: isEnabled,
                  onTap: () =>
                      setState(() => _activeAudioPreference = 'advanced'),
                ),
              ],
            ),
          ),
          if (isEnabled) ...[
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(children: _buildAudioSubOptions(context)),
            ),
          ],
        ],
      );
    } else if (_selectedType == 'image') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _IconChip(
                  title: 'Format',
                  icon: Icons.image_rounded,
                  isSelected: _activeImagePreference == 'format',
                  isEnabled: isEnabled,
                  onTap: () =>
                      setState(() => _activeImagePreference = 'format'),
                ),
                const SizedBox(width: 8),
                _IconChip(
                  title: 'Quality',
                  icon: Icons.high_quality_rounded,
                  isSelected: _activeImagePreference == 'quality',
                  isEnabled: isEnabled,
                  onTap: () =>
                      setState(() => _activeImagePreference = 'quality'),
                ),
                const SizedBox(width: 8),
                _IconChip(
                  title: 'Advanced',
                  icon: Icons.settings_suggest_rounded,
                  isSelected: _activeImagePreference == 'advanced',
                  isEnabled: isEnabled,
                  onTap: () =>
                      setState(() => _activeImagePreference = 'advanced'),
                ),
              ],
            ),
          ),
          if (isEnabled) ...[
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(children: _buildImageSubOptions(context)),
            ),
          ],
        ],
      );
    }

    // Default Types
    return const SizedBox.shrink();
  }

  List<Widget> _buildImageSubOptions(BuildContext context) {
    if (_activeImagePreference == 'format') {
      return [
        _TextChip(
          title: 'Original',
          isSelected: _selectedImageCodec == 'original',
          onTap: () => setState(() => _selectedImageCodec = 'original'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: 'JPG',
          isSelected: _selectedImageCodec == 'jpg',
          onTap: () => setState(() => _selectedImageCodec = 'jpg'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: 'PNG',
          isSelected: _selectedImageCodec == 'png',
          onTap: () => setState(() => _selectedImageCodec = 'png'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: 'WEBP',
          isSelected: _selectedImageCodec == 'webp',
          onTap: () => setState(() => _selectedImageCodec = 'webp'),
        ),
      ];
    } else if (_activeImagePreference == 'quality') {
      final qualities = ['Original', 'High', 'Balanced'];
      return qualities
          .map(
            (q) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TextChip(
                title: q,
                isSelected: _selectedImageQuality == q.toLowerCase(),
                onTap: () =>
                    setState(() => _selectedImageQuality = q.toLowerCase()),
              ),
            ),
          )
          .toList();
    } else {
      // Advanced
      return [
        _TextChip(
          title: 'Strip Metadata',
          isSelected: _selectedImageAdvanced.contains('strip_metadata'),
          onTap: () => _toggleImageAdvanced('strip_metadata'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: 'Grayscale',
          isSelected: _selectedImageAdvanced.contains('grayscale'),
          onTap: () => _toggleImageAdvanced('grayscale'),
        ),
      ];
    }
  }

  void _toggleImageAdvanced(String key) {
    setState(() {
      if (_selectedImageAdvanced.contains(key)) {
        _selectedImageAdvanced.remove(key);
      } else {
        _selectedImageAdvanced.add(key);
      }
    });
  }

  List<Widget> _buildVideoSubOptions(BuildContext context) {
    if (_activeVideoPreference == 'quality') {
      return [
        _TextChip(
          title: 'Compatible (H.264)',
          isSelected: _selectedCodec == 'h264',
          onTap: () => setState(() => _selectedCodec = 'h264'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: 'Efficient (HEVC)',
          isSelected: _selectedCodec == 'hevc',
          onTap: () => setState(() => _selectedCodec = 'hevc'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: 'Ultra (AV1)',
          isSelected: _selectedCodec == 'av1',
          onTap: () => setState(() => _selectedCodec = 'av1'),
        ),
      ];
    } else if (_activeVideoPreference == 'resolution') {
      final resolutions = ['360p', '480p', '720p', '1080p', '2K', '4K'];
      return resolutions
          .map(
            (res) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TextChip(
                title: res,
                isSelected: _selectedResolution == res,
                onTap: () => setState(() => _selectedResolution = res),
              ),
            ),
          )
          .toList();
    } else {
      // Audio inside Video
      return [
        _TextChip(
          title: 'AAC (M4A)',
          isSelected: _selectedVideoAudioFormat == 'm4a',
          onTap: () => setState(() => _selectedVideoAudioFormat = 'm4a'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: 'OPUS',
          isSelected: _selectedVideoAudioFormat == 'opus',
          onTap: () => setState(() => _selectedVideoAudioFormat = 'opus'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: 'MP3',
          isSelected: _selectedVideoAudioFormat == 'mp3',
          onTap: () => setState(() => _selectedVideoAudioFormat = 'mp3'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            width: 1,
            height: 24,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        _TextChip(
          title: '32kbps',
          isSelected: _selectedVideoAudioBitrate == '32k',
          onTap: () => setState(() => _selectedVideoAudioBitrate = '32k'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: '64kbps',
          isSelected: _selectedVideoAudioBitrate == '64k',
          onTap: () => setState(() => _selectedVideoAudioBitrate = '64k'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: '128kbps',
          isSelected: _selectedVideoAudioBitrate == '128k',
          onTap: () => setState(() => _selectedVideoAudioBitrate = '128k'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: '192kbps',
          isSelected: _selectedVideoAudioBitrate == '192k',
          onTap: () => setState(() => _selectedVideoAudioBitrate = '192k'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: '320kbps',
          isSelected: _selectedVideoAudioBitrate == '320k',
          onTap: () => setState(() => _selectedVideoAudioBitrate = '320k'),
        ),
      ];
    }
  }

  List<Widget> _buildAudioSubOptions(BuildContext context) {
    if (_activeAudioPreference == 'format') {
      return [
        _TextChip(
          title: 'MP3',
          isSelected: _selectedAudioCodec == 'mp3',
          onTap: () => setState(() => _selectedAudioCodec = 'mp3'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: 'M4A',
          isSelected: _selectedAudioCodec == 'm4a',
          onTap: () => setState(() => _selectedAudioCodec = 'm4a'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: 'OPUS',
          isSelected: _selectedAudioCodec == 'opus',
          onTap: () => setState(() => _selectedAudioCodec = 'opus'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: 'FLAC',
          isSelected: _selectedAudioCodec == 'flac',
          onTap: () => setState(() => _selectedAudioCodec = 'flac'),
        ),
      ];
    } else if (_activeAudioPreference == 'quality') {
      final bitrates = ['128k', '192k', '256k', '320k'];
      return bitrates
          .map(
            (rate) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TextChip(
                title: '${rate}kbps',
                isSelected: _selectedAudioBitrate == rate,
                onTap: () => setState(() => _selectedAudioBitrate = rate),
              ),
            ),
          )
          .toList();
    } else {
      // Advanced
      return [
        _TextChip(
          title: 'Unconverted',
          isSelected: _selectedAudioAdvanced.contains('unconverted'),
          onTap: () => _toggleAudioAdvanced('unconverted'),
        ),
        const SizedBox(width: 8),
        _TextChip(
          title: 'Mono',
          isSelected: _selectedAudioAdvanced.contains('mono'),
          onTap: () => _toggleAudioAdvanced('mono'),
        ),
      ];
    }
  }

  void _toggleAudioAdvanced(String key) {
    setState(() {
      if (_selectedAudioAdvanced.contains(key)) {
        _selectedAudioAdvanced.remove(key);
      } else {
        _selectedAudioAdvanced.add(key);
      }
    });
  }

  Widget _buildAdditionalSection(BuildContext context) {
    List<Widget> chips = [];
    if (_selectedType == 'image') {
      chips = [
        _TextChip(
          title: 'Upscale',
          isSelected: _selectedAdditional.contains('upscale'),
          onTap: () => _toggleAdditional('upscale'),
        ),
        _TextChip(
          title: 'Zipped',
          isSelected: _selectedAdditional.contains('zipped'),
          onTap: () => _toggleAdditional('zipped'),
        ),
      ];
    } else {
      chips = [
        _TextChip(
          title: 'Download Playlist',
          isSelected: _selectedAdditional.contains('playlist'),
          onTap: () => _toggleAdditional('playlist'),
        ),
        _TextChip(
          title: 'Download Subtitles',
          isSelected: _selectedAdditional.contains('subtitles'),
          onTap: () => _toggleAdditional('subtitles'),
        ),
        _TextChip(
          title: 'Save Thumbnail',
          isSelected: _selectedAdditional.contains('thumbnail'),
          onTap: () => _toggleAdditional('thumbnail'),
        ),
        _TextChip(
          title: 'Volume Normalize',
          isSelected: _selectedAdditional.contains('normalize'),
          onTap: () => _toggleAdditional('normalize'),
        ),
      ];
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (int i = 0; i < chips.length; i++) ...[
            chips[i],
            if (i < chips.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.metadata == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Analyzing link...',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    final meta = widget.metadata!;
    final List<String> images = (meta.isPhoto && meta.galleryUrls.isNotEmpty)
        ? meta.galleryUrls.where((url) => url.isNotEmpty).toSet().toList()
        : [meta.thumbnailUrl ?? ''];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AspectRatio(
                aspectRatio: images.length > 1 ? 4 / 3 : 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      if (images.length > 1)
                        PageView.builder(
                          controller: _pageController,
                          onPageChanged: (i) =>
                              setState(() => _currentPage = i),
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            return _buildImageItem(
                              context,
                              images[index],
                              index,
                            );
                          },
                        )
                      else
                        _buildImageItem(context, images[0], 0),

                      // Selection Counter & Batch Toggle
                      if (images.length > 1) ...[
                        Positioned(
                          top: 16,
                          left: 16,
                          child: GestureDetector(
                            onTap: () => _toggleSelectAll(!_selectAll),
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.black.withValues(alpha: 0.7)
                                    : Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: colorScheme.outline.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _selectAll
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    size: 16,
                                    color: _selectAll
                                        ? colorScheme.primary
                                        : (Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black.withValues(
                                                  alpha: 0.4,
                                                )),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SELECT ALL',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black.withValues(alpha: 0.8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.black.withValues(alpha: 0.7)
                                  : Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outline.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              '${_currentPage + 1}/${images.length}',
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Author/Metadata columns
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meta.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    meta.author ?? 'Unknown Channel',
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getPlatformIcon(meta.platform),
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getPlatformName(meta.platform),
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageItem(BuildContext context, String url, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: colorScheme.surfaceContainerHighest,
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            color: colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.image_not_supported_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (_selectedImages.length > 1)
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedImages[index] = !_selectedImages[index];
                  _selectAll = _selectedImages.every((e) => e);
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedImages[index]
                      ? colorScheme.primary
                      : Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: _selectedImages[index]
                      ? colorScheme.onPrimary
                      : Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _toggleSelectAll(bool value) {
    setState(() {
      _selectAll = value;
      for (int i = 0; i < _selectedImages.length; i++) {
        _selectedImages[i] = value;
      }
    });
  }

  String _getDownloadButtonText() {
    final size = _calculateTotalSize();
    if (_selectedType == 'image') {
      final selectedCount = _selectedImages.where((e) => e).length;
      final totalCount = _selectedImages.length;
      if (selectedCount == 1 && totalCount == 1) {
        return 'Download Image ($size)';
      }
      return 'Download $selectedCount/$totalCount Images ($size)';
    }
    return 'Download ${_selectedType.toUpperCase()} ($size)';
  }

  String _calculateTotalSize() {
    if (widget.metadata == null) return '0 MB';

    final meta = widget.metadata!;
    if (_selectedType == 'image') {
      final count = _selectedImages.where((e) => e).length;
      // Heuristic: ~2.4MB per HD image
      return '${(count * 2.4).toStringAsFixed(1)} MB';
    }

    // Try to find selected format size
    double? sizeInBytes;
    if (_selectedFormat == 'auto') {
      // Find best format based on type
      final formats = meta.availableFormats.where(
        (f) => _selectedType == 'video' ? f.isVideo : !f.isVideo,
      );
      if (formats.isNotEmpty) {
        sizeInBytes = formats.first.sizeBytes.toDouble();
      }
    } else {
      // Logic for custom format could go here
    }

    if (sizeInBytes != null && sizeInBytes > 0) {
      if (sizeInBytes > 1024 * 1024) {
        return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else {
        return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
      }
    }

    // Fallbacks
    return _selectedType == 'video' ? '~42 MB' : '~6.8 MB';
  }

  void _toggleAdditional(String key) {
    setState(() {
      if (_selectedAdditional.contains(key)) {
        _selectedAdditional.remove(key);
      } else {
        _selectedAdditional.add(key);
      }
    });
  }

  IconData _getPlatformIcon(String? platform) {
    platform = platform?.toLowerCase() ?? '';
    if (platform.contains('youtube')) return Icons.play_circle_fill_rounded;
    if (platform.contains('instagram')) return Icons.camera_alt_rounded;
    if (platform.contains('tiktok')) return Icons.music_note_rounded;
    if (platform.contains('facebook')) return Icons.facebook_rounded;
    if (platform.contains('twitter') || platform.contains(' x ')) {
      return Icons.close_rounded;
    }
    if (platform.contains('reddit')) return Icons.reddit_rounded;
    return Icons.language_rounded;
  }

  String _getPlatformName(String? platform) {
    platform = platform?.toLowerCase() ?? '';
    if (platform.contains('youtube')) return 'YouTube';
    if (platform.contains('instagram')) return 'Instagram';
    if (platform.contains('tiktok')) return 'TikTok';
    if (platform.contains('facebook')) return 'Facebook';
    if (platform.contains('twitter') || platform.contains(' x ')) return 'X';
    if (platform.contains('reddit')) return 'Reddit';
    return widget.metadata?.platform ?? 'Social';
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _PillToggle extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PillToggle({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? Colors.transparent : colorScheme.outlineVariant,
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallPillToggle extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SmallPillToggle({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? Colors.transparent : colorScheme.outlineVariant,
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _IconChip({
    required this.title,
    required this.icon,
    required this.isSelected,
    this.isEnabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool effectiveSelected = isSelected && isEnabled;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: Material(
        color: effectiveSelected
            ? colorScheme.primaryContainer
            : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: effectiveSelected
                ? Colors.transparent
                : (isEnabled
                      ? colorScheme.outlineVariant
                      : colorScheme.outlineVariant.withValues(alpha: 0.5)),
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: effectiveSelected
                      ? colorScheme.onPrimaryContainer
                      : (isEnabled
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: effectiveSelected
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: effectiveSelected
                        ? colorScheme.onPrimaryContainer
                        : (isEnabled
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextChip extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TextChip({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? colorScheme.tertiaryContainer : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? Colors.transparent : colorScheme.outlineVariant,
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? colorScheme.onTertiaryContainer
                  : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
