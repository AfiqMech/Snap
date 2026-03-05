import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'dart:math' as math;
import '../components/bouncing_button.dart';

class CompressImageItem {
  final File file;
  final int originalSize;
  final TextEditingController nameController;

  CompressImageItem({
    required this.file,
    required this.originalSize,
    required String initialName,
  }) : nameController = TextEditingController(text: initialName);
}

class ImageCompressScreen extends StatefulWidget {
  const ImageCompressScreen({super.key});

  @override
  State<ImageCompressScreen> createState() => _ImageCompressScreenState();
}

class _ImageCompressScreenState extends State<ImageCompressScreen> {
  final List<CompressImageItem> _selectedItems = [];

  // Image Settings
  double _imageQuality = 70;
  bool _limitTo1MB = false;
  String _targetFormat = 'JPEG';
  bool _removeMetadata = true;

  String _formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  int get _totalOriginalSize {
    return _selectedItems.fold(0, (sum, item) => sum + item.originalSize);
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    List<CompressImageItem> newItems = [];
    for (var f in result.files) {
      if (f.path != null) {
        final file = File(f.path!);
        final size = await file.length();
        newItems.add(
          CompressImageItem(
            file: file,
            originalSize: size,
            initialName: p.basenameWithoutExtension(file.path),
          ),
        );
      }
    }

    setState(() {
      _selectedItems.addAll(newItems);
    });
  }

  Future<void> _processImages() async {
    if (_selectedItems.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting batch compression in background...'),
      ),
    );

    Navigator.pop(context, {
      'files': _selectedItems.map((e) => e.file.path).toList(),
      'fileNames': _selectedItems
          .map((e) => e.nameController.text.trim())
          .toList(),
      'quality': _imageQuality.toInt(),
      'limitTo1MB': _limitTo1MB,
      'format': _targetFormat,
      'removeMetadata': _removeMetadata,
    });
  }

  void _removeItem(CompressImageItem item) {
    setState(() {
      _selectedItems.remove(item);
    });
  }

  Widget _buildPresetChip({
    required String label,
    required String sizeHint,
    required double targetQuality,
    required bool smartCompress,
    required IconData? icon,
    bool isPrimary = false,
  }) {
    final isSelected =
        _imageQuality == targetQuality && _limitTo1MB == smartCompress;
    final colorScheme = Theme.of(context).colorScheme;

    return BouncingButton(
      onPressed: _selectedItems.isEmpty
          ? null
          : () {
              setState(() {
                _imageQuality = targetQuality;
                _limitTo1MB = smartCompress;
              });
            },
      child: ActionChip(
        onPressed: _selectedItems.isEmpty
            ? null
            : () {
                setState(() {
                  _imageQuality = targetQuality;
                  _limitTo1MB = smartCompress;
                });
              },
        backgroundColor: isSelected
            ? (isPrimary
                  ? colorScheme.primaryContainer
                  : colorScheme.secondaryContainer)
            : colorScheme.surface,
        side: BorderSide(
          color: isSelected ? Colors.transparent : colorScheme.outline,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        avatar: icon != null
            ? Icon(
                icon,
                size: 18,
                color: isSelected
                    ? (isPrimary
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSecondaryContainer)
                    : colorScheme.onSurfaceVariant,
              )
            : null,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (isPrimary
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSecondaryContainer)
                    : (_selectedItems.isEmpty
                          ? colorScheme.onSurface.withValues(alpha: 0.38)
                          : colorScheme.onSurface),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              sizeHint,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? (isPrimary ? colorScheme.primary : colorScheme.secondary)
                    : (_selectedItems.isEmpty
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.38)
                          : colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Image Compress',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Empty State OR Scrollable List
                if (_selectedItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: BouncingButton(
                      onPressed: _pickImages,
                      child: GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.image_rounded,
                                size: 48,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Tap to select images',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'JPG, PNG, WEBP',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Source: ${_selectedItems.length} Images',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _formatBytes(_totalOriginalSize),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedItems.length + 1,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            if (index == _selectedItems.length) {
                              // Add more button
                              return BouncingButton(
                                onPressed: _pickImages,
                                child: GestureDetector(
                                  onTap: _pickImages,
                                  child: Container(
                                    width: 140,
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant,
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo_rounded,
                                            color: colorScheme.primary,
                                            size: 32,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Add More',
                                            style: TextStyle(
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            final item = _selectedItems[index];
                            return SizedBox(
                              width: 140,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Image.file(
                                            item.file,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        // Remove button
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () => _removeItem(item),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.6,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: item.nameController,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: colorScheme.outlineVariant,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: colorScheme.outlineVariant,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatBytes(item.originalSize),
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Target Quality',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _selectedItems.isEmpty
                              ? colorScheme.onSurface.withValues(alpha: 0.38)
                              : colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${_imageQuality.toInt()}%',
                        style: TextStyle(
                          color: _selectedItems.isEmpty
                              ? colorScheme.primary.withValues(alpha: 0.38)
                              : colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Slider(
                    value: _imageQuality,
                    min: 10,
                    max: 100,
                    divisions: 9,
                    onChanged: (_limitTo1MB || _selectedItems.isEmpty)
                        ? null
                        : (v) => setState(() => _imageQuality = v),
                  ),
                ),

                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Presets',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _selectedItems.isEmpty
                          ? colorScheme.onSurface.withValues(alpha: 0.38)
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      _buildPresetChip(
                        label: 'Profile',
                        sizeHint: '(~200KB)',
                        targetQuality: 90,
                        smartCompress: true,
                        icon: null,
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        label: 'Email',
                        sizeHint: '(~1MB)',
                        targetQuality: 60,
                        smartCompress: false,
                        icon: Icons.check,
                        isPrimary: true,
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        label: 'Social',
                        sizeHint: '(~4MB)',
                        targetQuality: 80,
                        smartCompress: false,
                        icon: null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Advanced Options',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _selectedItems.isEmpty
                                ? colorScheme.onSurface.withValues(alpha: 0.38)
                                : colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Smart Compress',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedItems.isEmpty
                                          ? colorScheme.onSurface.withValues(
                                              alpha: 0.38,
                                            )
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Auto-adjust quality to hit low size',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedItems.isEmpty
                                          ? colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.38)
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _limitTo1MB,
                              onChanged: _selectedItems.isEmpty
                                  ? null
                                  : (v) => setState(() {
                                      _limitTo1MB = v;
                                      if (v) {
                                        _imageQuality = 90;
                                      }
                                    }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Format',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedItems.isEmpty
                                          ? colorScheme.onSurface.withValues(
                                              alpha: 0.38,
                                            )
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Select output format',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedItems.isEmpty
                                          ? colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.38)
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _targetFormat,
                                  isDense: true,
                                  borderRadius: BorderRadius.circular(16),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                  items: ['JPEG', 'PNG', 'WEBP'].map((
                                    String value,
                                  ) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: _selectedItems.isEmpty
                                      ? null
                                      : (String? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              _targetFormat = newValue;
                                            });
                                          }
                                        },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Remove Metadata',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedItems.isEmpty
                                          ? colorScheme.onSurface.withValues(
                                              alpha: 0.38,
                                            )
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Strip EXIF and location data',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedItems.isEmpty
                                          ? colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.38)
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _removeMetadata,
                              onChanged: _selectedItems.isEmpty
                                  ? null
                                  : (v) => setState(() => _removeMetadata = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 120), // Padding for bottom button
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
                onPressed: _selectedItems.isEmpty ? null : _processImages,
                child: FilledButton.icon(
                  onPressed: _selectedItems.isEmpty ? null : _processImages,
                  icon: const Icon(Icons.compress),
                  label: Text(
                    _selectedItems.isEmpty
                        ? 'Compress Image'
                        : 'Compress ${_selectedItems.length} Image${_selectedItems.length > 1 ? 's' : ''}',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
