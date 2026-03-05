import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path/path.dart' as p;
import 'dart:math' as math;
import '../components/bouncing_button.dart';

class VideoCompressScreen extends StatefulWidget {
  const VideoCompressScreen({super.key});

  @override
  State<VideoCompressScreen> createState() => _VideoCompressScreenState();
}

class _VideoCompressScreenState extends State<VideoCompressScreen> {
  File? _selectedFile;
  int _originalSize = 0;
  int _estimatedSize = 0;

  // Video Settings
  VideoQuality _videoQuality = VideoQuality.MediumQuality;
  String _videoPreset = 'Discord';
  bool _muteAudio = false;
  String _targetFormat = 'MP4';
  final List<String> _formats = ['MP4', 'MOV', 'AVI', 'WEBM'];
  final TextEditingController _fileNameController = TextEditingController();

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final size = await file.length();

    setState(() {
      _selectedFile = file;
      _originalSize = size;
      _fileNameController.text = p.basenameWithoutExtension(file.path);

      // Auto-set slider based on preset
      _updateEstimatedSize();
    });
  }

  void _updateEstimatedSize() {
    double ratio = 1.0;
    switch (_videoQuality) {
      case VideoQuality.LowQuality:
        ratio = 0.3;
        break;
      case VideoQuality.MediumQuality:
        ratio = 0.5;
        break;
      case VideoQuality.HighestQuality:
        ratio = 0.9;
        break;
      default:
        ratio = 0.5;
    }
    _estimatedSize = (_originalSize * ratio).toInt();
  }

  Future<void> _processVideo() async {
    if (_selectedFile == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting compression in background...')),
    );

    Navigator.pop(context, {
      'file': _selectedFile!.path,
      'quality': _videoQuality,
      'muteAudio': _muteAudio,
      'format': _targetFormat,
      'fileName': _fileNameController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Video Compress',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Source Section
                const Text(
                  'Source',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                BouncingButton(
                  onPressed: _pickVideo,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _selectedFile == null
                            ? colorScheme.outlineVariant
                            : colorScheme.primary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _selectedFile == null
                        ? AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.movie_rounded,
                                      size: 48,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Tap to select a video',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Icon(
                                    Icons.movie_creation_outlined,
                                    size: 64,
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 16,
                                  bottom: 16,
                                  right: 48,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        p.basename(_selectedFile!.path),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatBytes(_originalSize),
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    onPressed: () => setState(() {
                                      _selectedFile = null;
                                      _estimatedSize = 0;
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),
                Opacity(
                  opacity: _selectedFile == null ? 0.4 : 1.0,
                  child: IgnorePointer(
                    ignoring: _selectedFile == null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        const Text(
                          'Output Filename',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _fileNameController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest,
                            suffixText: '.$_targetFormat',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),

                        // File Size Estimation Section
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Estimated Size',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '~${_formatBytes(_estimatedSize)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: _videoQuality == VideoQuality.LowQuality
                              ? 0
                              : (_videoQuality == VideoQuality.MediumQuality
                                    ? 1
                                    : 2),
                          min: 0,
                          max: 2,
                          divisions: 2,
                          label: _videoQuality.name.replaceAll('Quality', ''),
                          onChanged: (val) {
                            setState(() {
                              if (val == 0) {
                                _videoQuality = VideoQuality.LowQuality;
                              } else if (val == 1) {
                                _videoQuality = VideoQuality.MediumQuality;
                              } else {
                                _videoQuality = VideoQuality.HighestQuality;
                              }
                              _videoPreset = 'Custom';
                              _updateEstimatedSize();
                            });
                          },
                        ),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Small', style: TextStyle(fontSize: 12)),
                            Text(
                              'High Quality',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Presets',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildPresetChip(
                                'Discord',
                                Icons.discord,
                                VideoQuality.LowQuality,
                              ),
                              const SizedBox(width: 8),
                              _buildPresetChip(
                                'WhatsApp',
                                Icons.chat,
                                VideoQuality.MediumQuality,
                              ),
                              const SizedBox(width: 8),
                              _buildPresetChip(
                                'Instagram',
                                Icons.camera_alt,
                                VideoQuality.HighestQuality,
                              ),
                              const SizedBox(width: 8),
                              _buildPresetChip(
                                'TikTok',
                                Icons.music_note,
                                VideoQuality.HighestQuality,
                              ),
                              const SizedBox(width: 8),
                              _buildPresetChip(
                                'Assignment',
                                Icons.school,
                                VideoQuality.MediumQuality,
                              ),
                              const SizedBox(width: 8),
                              _buildPresetChip(
                                'Archive (HQ)',
                                Icons.inventory_2,
                                VideoQuality.HighestQuality,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        const Text(
                          'Video Format',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _formats.map((format) {
                              final isSelected = _targetFormat == format;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: BouncingButton(
                                  onPressed: () {
                                    setState(() => _targetFormat = format);
                                  },
                                  child: ChoiceChip(
                                    label: Text(format),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _targetFormat = format);
                                      }
                                    },
                                    selectedColor: colorScheme.primary,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    side: BorderSide.none,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 32),
                        const Text(
                          'Advanced Options',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: SwitchListTile(
                            title: const Text(
                              'Mute Audio',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text('Removes entire audio track'),
                            value: _muteAudio,
                            onChanged: (val) =>
                                setState(() => _muteAudio = val),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 120), // Padding for button
              ],
            ),
          ),

          // Bottom Action Area
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: BouncingButton(
                onPressed: _selectedFile == null ? null : _processVideo,
                child: FilledButton.icon(
                  onPressed: _selectedFile == null ? null : _processVideo,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.compress),
                  label: const Text(
                    'Compress Video',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(
    String label,
    IconData icon,
    VideoQuality quality, {
    Color? overrideColor,
  }) {
    final isSelected = _videoPreset == label;
    final colorScheme = Theme.of(context).colorScheme;

    // Icon color: Use overrideColor if provided, otherwise default Material behavior
    final iconColor =
        overrideColor ??
        (isSelected ? colorScheme.onPrimary : colorScheme.primary);

    // Background color: Use default Material behavior
    final backgroundColor = isSelected
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;

    return BouncingButton(
      onPressed: () {
        setState(() {
          _videoPreset = label;
          _videoQuality = quality;
          _updateEstimatedSize();
        });
      },
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: iconColor),
        label: Text(label),
        backgroundColor: backgroundColor,
        labelStyle: TextStyle(
          color: isSelected
              ? colorScheme.onPrimary
              : colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () {
          setState(() {
            _videoPreset = label;
            _videoQuality = quality;
            _updateEstimatedSize();
          });
        },
      ),
    );
  }
}
