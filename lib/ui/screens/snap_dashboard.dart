import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'history_screen.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../core/models/media_metadata.dart';
import '../../features/extraction/extraction_progress.dart' as progress_models;
import '../../core/services/settings_service.dart';
import '../../core/services/history_service.dart';
import '../viewmodel/snap_view_model.dart';
import '../components/download_config_sheet.dart';
import '../components/bouncing_button.dart';
import 'settings_screen.dart';
import 'dashboard/toolkit_section.dart';
import 'dashboard/recent_activity_section.dart';
import 'dashboard/storage_status_bar.dart';

class SnapDashboard extends StatefulWidget {
  const SnapDashboard({super.key});

  @override
  State<SnapDashboard> createState() => _SnapDashboardState();
}

class _SnapDashboardState extends State<SnapDashboard> {
  static const platform = MethodChannel('com.example.snap/storage');

  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();

  Map<String, int>? _storageInfo;
  Timer? _storageTimer;
  bool _isQuickMode = false;
  bool _isCheckingLaunchMode = true;

  late StreamSubscription _intentDataStreamSubscription;

  void _handleSharedIntent(List<SharedMediaFile> value) {
    if (value.isEmpty) return;
    String sharedText = value.first.path;

    if (sharedText.isNotEmpty && sharedText.contains('http')) {
      final RegExp urlRegExp = RegExp(r'(https?://[^\s]+)');
      final match = urlRegExp.firstMatch(sharedText);
      final cleanUrl = match?.group(0) ?? sharedText;

      setState(() {
        _isQuickMode = true; // Hide Dashboard UI immediately
        _urlController.text = cleanUrl;
      });

      setState(() {
        _isQuickMode = true; // Force overlay mode immediately
        _urlController.text = cleanUrl;
      });

      // Auto analyze and show config sheet immediately
      _analyzeCurrentUrl();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchStorageInfo();
    // Real-time tracking: refresh every 30 seconds
    _storageTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchStorageInfo();
    });

    // Listen to media sharing incoming from outside
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            _handleSharedIntent(value);
          },
          onError: (err) {
            debugPrint("getIntentDataStream error: $err");
          },
        );

    // Get the media sharing coming from outside while app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) async {
      await _handleInitialLaunch(value);
      ReceiveSharingIntent.instance.reset(); // clear
    });
  }

  Future<void> _handleInitialLaunch(List<SharedMediaFile> value) async {
    final launchMode = await platform.invokeMethod('getLaunchMode');
    if (launchMode == 'quick' || value.isNotEmpty) {
      setState(() {
        _isQuickMode = true;
      });
    }
    _handleSharedIntent(value);
    setState(() {
      _isCheckingLaunchMode = false;
    });
  }

  Future<void> _fetchStorageInfo() async {
    if (!Platform.isAndroid) return;
    try {
      final result = await platform.invokeMethod('getStorageInfo');
      if (mounted && result != null) {
        setState(() {
          _storageInfo = Map<String, int>.from(result as Map);
        });
      }
    } catch (e) {
      debugPrint("Storage fetch error: $e");
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _storageTimer?.cancel();
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  void _analyzeCurrentUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a valid URL')));
      return;
    }
    _urlFocusNode.unfocus();
    context.read<SnapViewModel>().analyzeUrl(url);
  }

  void _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      setState(() {
        _urlController.text = clipboardData!.text!;
      });
      // Deliberately not auto-analyzing here to respect user preference
    }
  }

  Future<void> _checkPermissionsAndDownload(
    MediaMetadata metadata,
    String formatId,
    SnapViewModel viewModel,
  ) async {
    if (Platform.isAndroid) {
      if (await Permission.photos.isDenied ||
          await Permission.videos.isDenied ||
          await Permission.audio.isDenied) {
        await [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ].request();
      }
    }

    bool hasPermission = false;
    if (Platform.isAndroid) {
      hasPermission =
          await Permission.photos.isGranted ||
          await Permission.videos.isGranted ||
          await Permission.audio.isGranted ||
          await Permission.storage.isGranted;
    } else {
      hasPermission = await Permission.storage.isGranted;
    }

    if (hasPermission) {
      Future.delayed(Duration.zero, () {
        if (!mounted) return;
        String downloadPath = context.read<SettingsService>().downloadPath;
        Directory(downloadPath).createSync(recursive: true);

        viewModel.startDownload(
          metadata,
          formatId,
          downloadPath,
          context.read<SettingsService>(),
        );
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to download files'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer2<SnapViewModel, HistoryService>(
      builder: (context, viewModel, historyService, child) {
        final state = viewModel.state;
        final historyItems = historyService.items;
        final isProcessing =
            state is progress_models.Analyzing ||
            state is progress_models.Downloading;

        // Show config sheet only when metadata is successfully extracted
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (viewModel.metadata != null && !viewModel.hasShownConfigSheet) {
            viewModel.markConfigSheetShown();
            DownloadConfigSheet.show(context, viewModel.metadata, (formatId) {
              if (viewModel.metadata != null) {
                _checkPermissionsAndDownload(
                  viewModel.metadata!,
                  formatId,
                  viewModel,
                );
              }
            }, isQuickMode: _isQuickMode).then((value) {
              if (value == 'open_full') {
                setState(() {
                  _isQuickMode = false;
                });
              } else if (_isQuickMode) {
                SystemNavigator.pop();
              }
            });
          }
        });

        if (_isCheckingLaunchMode) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: SizedBox.shrink(),
          );
        }

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: _isQuickMode
              ? Colors.transparent
              : colorScheme.surface,
          body: _isQuickMode
              ? (state is progress_models.Analyzing
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                state.status.isNotEmpty
                                    ? state.status
                                    : 'Analyzing Link...',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : (state is progress_models.Error
                          ? Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(100),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: colorScheme.onErrorContainer,
                                    ),
                                    const SizedBox(width: 16),
                                    Flexible(
                                      child: Text(
                                        state.message.isNotEmpty
                                            ? state.message
                                            : 'Failed to analyze link',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onErrorContainer,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink()))
              : Stack(
                  children: [
                    // Subtle background pattern or noise could be drawn here, but keeping it clean per modern guidelines
                    SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 12.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Snap',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.5,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.history_rounded,
                                        size: 28,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const HistoryScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.settings_rounded,
                                        size: 28,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const SettingsScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              children: [
                                // Input Section
                                _AnimatedPasteBar(
                                  controller: _urlController,
                                  focusNode: _urlFocusNode,
                                  isProcessing: isProcessing,
                                  onAnalyze: _analyzeCurrentUrl,
                                  onChanged: () => setState(() {}),
                                ),

                                const SizedBox(height: 24),

                                // Toolkit Section
                                _sectionHeader(context, 'Toolkit'),
                                const SizedBox(height: 16),
                                const ToolkitSection(),

                                const SizedBox(height: 32),

                                // Recent Activity Section
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _sectionHeader(context, 'Recent Activity'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                RecentActivitySection(history: historyItems),

                                // Bottom padding to ensure scrollable content goes above sticky storage bar
                                const SizedBox(height: 120),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom Sticky Overlays
                    ..._buildFloatingLayout(context),
                  ],
                ),
        );
      },
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: colorScheme.onSurface,
        letterSpacing: -0.5,
      ),
    );
  }

  List<Widget> _buildFloatingLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return [
      Positioned(
        bottom: 24,
        right: 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_urlController.text.isNotEmpty) ...[
              SizedBox(
                width: 56,
                height: 56,
                child: BouncingButton(
                  onPressed: () {
                    setState(() => _urlController.clear());
                  },
                  child: FloatingActionButton(
                    heroTag: 'clear_fab',
                    onPressed: () {
                      setState(() => _urlController.clear());
                    },
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    foregroundColor: colorScheme.onSurfaceVariant,
                    elevation: 2,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.close_rounded, size: 28),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 64,
                height: 64,
                child: BouncingButton(
                  onPressed: _analyzeCurrentUrl,
                  child: FloatingActionButton(
                    heroTag: 'analyze_fab',
                    onPressed: _analyzeCurrentUrl,
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    elevation: 4,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.arrow_forward_rounded, size: 32),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: 56,
                height: 56,
                child: BouncingButton(
                  onPressed: () {
                    DownloadConfigSheet.show(context, null, (quality) {
                      _analyzeCurrentUrl();
                    });
                  },
                  child: FloatingActionButton(
                    heroTag: 'config_fab',
                    onPressed: () {
                      DownloadConfigSheet.show(context, null, (quality) {
                        _analyzeCurrentUrl();
                      });
                    },
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.onSurface,
                    elevation: 2,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.tune_rounded, size: 28),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 64,
                height: 64,
                child: BouncingButton(
                  onPressed: _pasteFromClipboard,
                  child: FloatingActionButton(
                    heroTag: 'paste_fab',
                    onPressed: _pasteFromClipboard,
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    elevation: 4,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.content_paste_rounded, size: 32),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      Positioned(
        bottom: 30,
        left: 16,
        right: 88,
        child: StorageStatusBar(storageInfo: _storageInfo),
      ),
    ];
  }
}

class _AnimatedPasteBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isProcessing;
  final VoidCallback onAnalyze;
  final VoidCallback onChanged;

  const _AnimatedPasteBar({
    required this.controller,
    required this.focusNode,
    required this.isProcessing,
    required this.onAnalyze,
    required this.onChanged,
  });

  @override
  State<_AnimatedPasteBar> createState() => _AnimatedPasteBarState();
}

class _AnimatedPasteBarState extends State<_AnimatedPasteBar>
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
  void didUpdateWidget(_AnimatedPasteBar oldWidget) {
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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Container(
            height: 64,
            padding: const EdgeInsets.all(3.0),
            decoration: BoxDecoration(
              color: widget.isProcessing
                  ? null
                  : colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(32),
              gradient: widget.isProcessing
                  ? SweepGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.tertiary,
                        colorScheme.primary,
                      ],
                      transform: GradientRotation(
                        _controller.value * 2 * 3.14159,
                      ),
                    )
                  : null,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(29),
              ),
              child: child,
            ),
          ),
        );
      },
      child: Row(
        children: [
          const SizedBox(width: 20),
          Icon(
            Icons.link_rounded,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              onChanged: (_) => widget.onChanged(),
              decoration: InputDecoration(
                hintText: 'Paste link here',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w400,
              ),
              onSubmitted: (_) {
                if (!widget.isProcessing) widget.onAnalyze();
              },
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
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
                      _controller.value * 2 * 3.14159,
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
