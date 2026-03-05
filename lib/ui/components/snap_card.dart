import 'package:flutter/material.dart';

class SnapCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const SnapCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding ?? const EdgeInsets.all(0), child: child),
    );
  }
}
