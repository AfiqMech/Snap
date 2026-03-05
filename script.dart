import 'dart:io';

void main() {
  final file = File('d:/Snap/lib/ui/screens/snap_dashboard.dart');
  final lines = file.readAsLinesSync();

  final List<String> newLines = [];
  bool inToolCards = false;
  bool inRecentActivity = false;
  bool skipMethods = false;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Replace usages of ToolCard
    if (line.contains('Row(') &&
        i > 0 &&
        lines[i - 1].contains('_sectionHeader(context, \'Toolkit\'),')) {
      newLines.add(line);
      newLines.add('                                  const ToolkitSection(),');
      inToolCards = true;
      continue;
    }
    if (inToolCards && line.contains('const SizedBox(height: 32),')) {
      inToolCards = false;
    }
    if (inToolCards) continue;

    // Replace usages of RecentActivity
    if (line.contains('_buildRecentActivitySection(')) {
      newLines.add('                                RecentActivitySection(');
      newLines.add('                                  history: historyItems,');
      newLines.add('                                ),');
      inRecentActivity = true;
      continue;
    }
    if (inRecentActivity && line.contains('),')) {
      inRecentActivity = false;
      continue;
    }
    if (inRecentActivity) continue; // Skip args like 'context,' 'viewModel,'

    // Remove old method declarations
    if (line.contains('Widget _buildToolCard(')) {
      skipMethods = true;
    }
    if (skipMethods && line.contains('Widget _sectionHeader(')) {
      skipMethods = false;
    }
    if (skipMethods) continue;

    // Remove storage text calculations
    if (line.contains('int totalMemory = _storageInfo?[\'total\'] ?? 1;')) {
      i += 8; // Skip the next 8 lines
      continue;
    }

    newLines.add(line);
  }

  file.writeAsStringSync(newLines.join('\n'));
  print('Successfully processed snap_dashboard.dart');
}
