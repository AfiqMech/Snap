import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/history_service.dart';
import '../../core/models/history_item.dart';
import '../components/bouncing_button.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedFilterType = 0; // 0: All, 1: Audio, 2: Video, 3: Image
  String _selectedPlatform = 'All';
  final Set<String> _expandedItemIds =
      {}; // Track which items show their source URL
  bool _isSelectionMode = false;
  final Set<String> _selectedItemIds = {};

  final List<String> _platforms = [
    'All',
    'Twitter',
    'TikTok',
    'YouTube',
    'Reddit',
    'X',
    'Discord',
    'Instagram',
    'Local',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final historyService = Provider.of<HistoryService>(context);

    final filteredItems = historyService.items.where((item) {
      final typeMatch =
          _selectedFilterType == 0 ||
          (_selectedFilterType == 1 && item.type == MediaType.audio) ||
          (_selectedFilterType == 2 && item.type == MediaType.video) ||
          (_selectedFilterType == 3 && item.type == MediaType.image);

      final platformMatch =
          _selectedPlatform == 'All' ||
          item.platform.toLowerCase() == _selectedPlatform.toLowerCase();

      return typeMatch && platformMatch;
    }).toList();

    final allSelected =
        filteredItems.isNotEmpty &&
        filteredItems.every((item) => _selectedItemIds.contains(item.id));

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
        title: const Text(
          'History',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: colorScheme.primary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.pop(
              context,
            ), // Typically leads to Settings, but pop allows going back since Dashboard has it
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media Type Filters
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTypePill(
                    icon: Icons.graphic_eq_rounded,
                    label: 'Audio',
                    isSelected: _selectedFilterType == 1,
                    onTap: () => setState(
                      () => _selectedFilterType = _selectedFilterType == 1
                          ? 0
                          : 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTypePill(
                    icon: Icons.movie_rounded,
                    label: 'Video',
                    isSelected: _selectedFilterType == 2,
                    onTap: () => setState(
                      () => _selectedFilterType = _selectedFilterType == 2
                          ? 0
                          : 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTypePill(
                    icon: Icons.image_rounded,
                    label: 'Image',
                    isSelected: _selectedFilterType == 3,
                    onTap: () => setState(
                      () => _selectedFilterType = _selectedFilterType == 3
                          ? 0
                          : 3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Platform Filters Scrollable Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: _platforms.map((platform) {
                final isSelected = _selectedPlatform == platform;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: BouncingButton(
                    onPressed: () {
                      setState(() => _selectedPlatform = platform);
                    },
                    child: ActionChip(
                      label: Text(platform),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                      ),
                      backgroundColor: isSelected
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      side: BorderSide(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                      ),
                      onPressed: () {
                        setState(() => _selectedPlatform = platform);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_isSelectionMode)
                  Text(
                    'RECENT DOWNLOADS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (!_isSelectionMode)
                  FilledButton.tonalIcon(
                    onPressed: () => setState(() => _isSelectionMode = true),
                    icon: const Icon(Icons.checklist_rounded, size: 18),
                    label: const Text(
                      'Select',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: const StadiumBorder(),
                    ),
                  )
                else
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              if (allSelected) {
                                _selectedItemIds.removeAll(
                                  filteredItems.map((e) => e.id),
                                );
                              } else {
                                _selectedItemIds.addAll(
                                  filteredItems.map((e) => e.id),
                                );
                              }
                            });
                          },
                          icon: Icon(
                            allSelected ? Icons.deselect : Icons.select_all,
                            size: 18,
                          ),
                          label: Text(
                            allSelected ? 'None' : 'All',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isSelectionMode = false;
                                  _selectedItemIds.clear();
                                });
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _selectedItemIds.isEmpty
                                  ? null
                                  : () => _showDeleteSelectionConfirmation(
                                      context,
                                    ),
                              icon: const Icon(Icons.delete_rounded, size: 18),
                              label: Text(
                                'Delete (${_selectedItemIds.length})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                backgroundColor: colorScheme.error,
                                foregroundColor: colorScheme.onError,
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Main List View (Empty State per instructions)
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'History is empty',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No items match the current filters.',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildHistoryItem(context, item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, HistoryItem item) {
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

    final isSelected = _selectedItemIds.contains(item.id);

    return BouncingButton(
      onPressed: () {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedItemIds.remove(item.id);
            } else {
              _selectedItemIds.add(item.id);
            }
          });
        }
      },
      child: GestureDetector(
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedItemIds.remove(item.id);
              } else {
                _selectedItemIds.add(item.id);
              }
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                : colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_isSelectionMode) ...[
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                  ],
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: colorScheme.surfaceContainerHighest,
                      child: item.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              item.thumbnailUrl,
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
                            fontWeight:
                                FontWeight.w900, // Heavier bold for titles
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '$dateStr • ${item.platform} • ${_formatFileSize(item.sizeBytes)}',
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
                              item.sourceUrl,
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
                ), // SizedBox
              ],
            ],
          ),
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

  Widget _buildTypePill({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return BouncingButton(
      onPressed: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteSelectionConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected'),
        content: Text(
          'Are you sure you want to delete ${_selectedItemIds.length} items from your history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final historyService = Provider.of<HistoryService>(
                context,
                listen: false,
              );
              for (final id in _selectedItemIds) {
                historyService.removeItem(id);
              }
              setState(() {
                _selectedItemIds.clear();
                _isSelectionMode = false;
              });
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              shape: const StadiumBorder(),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
