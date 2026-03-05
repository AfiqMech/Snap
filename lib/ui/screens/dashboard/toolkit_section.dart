import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/snap_view_model.dart';

import '../../components/bouncing_button.dart';
import '../video_compress_screen.dart';
import '../image_compress_screen.dart';
import 'package:video_compress/video_compress.dart';

class ToolkitSection extends StatelessWidget {
  const ToolkitSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewModel = context.watch<SnapViewModel>();

    return Row(
      children: [
        Expanded(
          child: _ToolCard(
            title: 'Video Compress',
            subtitle: 'Reduce size',
            icon: Icons.movie_rounded,
            containerColor: colorScheme.primaryContainer,
            onContainerColor: colorScheme.onPrimaryContainer,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VideoCompressScreen()),
              );
              if (result != null && result is Map<String, dynamic>) {
                viewModel.compressLocalVideo(
                  filePath: result['file'],
                  quality: result['quality'] as VideoQuality,
                  muteAudio: result['muteAudio'],
                  format: result['format'],
                  fileName: result['fileName'],
                );
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToolCard(
            title: 'Image Compress',
            subtitle: 'Optimize photos',
            icon: Icons.image_rounded,
            containerColor: colorScheme.tertiaryContainer,
            onContainerColor: colorScheme.onTertiaryContainer,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImageCompressScreen()),
              );
              if (result != null && result is Map<String, dynamic>) {
                viewModel.compressLocalImages(
                  filePaths: result['files'] as List<String>,
                  fileNames: result['fileNames'] as List<String>,
                  quality: result['quality'] as int,
                  limitTo1MB: result['limitTo1MB'] as bool,
                  format: result['format'] as String,
                  removeMetadata: result['removeMetadata'] as bool,
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _ToolCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color containerColor;
  final Color onContainerColor;
  final VoidCallback onTap;

  const _ToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.containerColor,
    required this.onContainerColor,
    required this.onTap,
  });

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  // Prevents multiple Navigator pushes from rapid taps
  bool _isNavigating = false;

  void _handleTap() {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    Future.microtask(() async {
      try {
        widget.onTap();
      } finally {
        if (mounted) setState(() => _isNavigating = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BouncingButton(
      onPressed: _handleTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: widget.containerColor,
          borderRadius: BorderRadius.circular(32),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Centered Icon with Background
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.onContainerColor.withValues(alpha: 0.1),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.onContainerColor.withValues(alpha: 0.2),
                  size: 64,
                ),
              ),
            ),
            // Bottom Overlay
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.onContainerColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, color: widget.onContainerColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: widget.onContainerColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: widget.onContainerColor.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
