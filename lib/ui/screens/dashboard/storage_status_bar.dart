import 'package:flutter/material.dart';

class StorageStatusBar extends StatelessWidget {
  final Map<String, int>? storageInfo;

  const StorageStatusBar({super.key, required this.storageInfo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    int totalMemory = storageInfo?['total'] ?? 1;
    int freeMemory = storageInfo?['free'] ?? 1;
    int usedMemory = totalMemory - freeMemory;
    double usePercentage = totalMemory > 1 ? (usedMemory / totalMemory) : 0.0;

    String totalStr = (totalMemory / 1024 / 1024 / 1024).toStringAsFixed(0);
    String usedStr = (usedMemory / 1024 / 1024 / 1024).toStringAsFixed(0);
    String percentStr = (usePercentage * 100).toStringAsFixed(0);
    String storageText = "$usedStr / $totalStr GB ($percentStr%)";

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Storage',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  storageText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: usePercentage,
                minHeight: 6,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
