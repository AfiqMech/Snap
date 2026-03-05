import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/settings_service.dart';
import 'instagram_login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _cacheSizeStr = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int size = 0;
      if (tempDir.existsSync()) {
        tempDir.listSync(recursive: true, followLinks: false).forEach((
          FileSystemEntity entity,
        ) {
          if (entity is File) {
            size += entity.lengthSync();
          }
        });
      }
      if (mounted) {
        setState(() {
          _cacheSizeStr = _formatSize(size);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cacheSizeStr = 'Unknown';
        });
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.listSync(recursive: true, followLinks: false).forEach((
          FileSystemEntity entity,
        ) {
          if (entity is File) {
            try {
              entity.deleteSync();
            } catch (_) {}
          }
        });
      }
      await _calculateCacheSize();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('App cache cleared')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to clear cache')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsService>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ),
      ),
      body: RepaintBoundary(
        child: ListView(
          padding: EdgeInsets.only(
            top: 24,
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 100,
          ),
          children: [
            _buildSectionHeader('Theme', colorScheme),
            _buildThemeSection(context, settings, colorScheme),
            const SizedBox(height: 32),

            _buildSectionHeader('Network & Background', colorScheme),
            _buildNetworkSection(context, settings, colorScheme),
            const SizedBox(height: 32),

            _buildSectionHeader('Notifications & Battery', colorScheme),
            _buildNotificationsSection(context, settings, colorScheme),
            const SizedBox(height: 32),

            _buildSectionHeader('General', colorScheme),
            _buildGeneralSection(context, settings, colorScheme),
            const SizedBox(height: 32),

            _buildSectionHeader('Content Preferences', colorScheme),
            _buildContentPreferencesSection(context, settings, colorScheme),
            const SizedBox(height: 32),

            _buildSectionHeader('Account & Authentication', colorScheme),
            _buildAccountSection(context, settings, colorScheme),
            const SizedBox(height: 32),

            _buildSectionHeader('Support & Social', colorScheme),
            _buildSupportSection(context, colorScheme),
            const SizedBox(height: 32),

            _buildFooter(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, bottom: 12.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCardContainer({
    required List<Widget> children,
    required ColorScheme colorScheme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildThemeSection(
    BuildContext context,
    SettingsService settings,
    ColorScheme colorScheme,
  ) {
    return _buildCardContainer(
      colorScheme: colorScheme,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Theme Mode',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 17),
              ),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildThemeModeButton(
                      ThemeMode.system,
                      'Auto',
                      settings,
                      colorScheme,
                    ),
                    _buildThemeModeButton(
                      ThemeMode.light,
                      'Light',
                      settings,
                      colorScheme,
                    ),
                    _buildThemeModeButton(
                      ThemeMode.dark,
                      'Dark',
                      settings,
                      colorScheme,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildDivider(colorScheme),
        _buildSwitchTile(
          title: 'Dynamic Color',
          subtitle: 'Match system color palette',
          value: settings.useDynamicColor,
          onChanged: (v) => settings.setDynamicColor(v),
          colorScheme: colorScheme,
        ),
        _buildDivider(colorScheme),
        _buildSwitchTile(
          title: 'OLED Dark Mode',
          subtitle: 'Pure black background in dark mode',
          value: settings.useOledDarkMode,
          onChanged: (v) => settings.setOledDarkMode(v),
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _buildThemeModeButton(
    ThemeMode mode,
    String label,
    SettingsService settings,
    ColorScheme colorScheme,
  ) {
    final isSelected = settings.themeMode == mode;
    return GestureDetector(
      onTap: () => settings.setThemeMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          border: isSelected
              ? Border.all(color: colorScheme.primary.withValues(alpha: 0.2))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 17,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colorScheme.onPrimary,
            activeTrackColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkSection(
    BuildContext context,
    SettingsService settings,
    ColorScheme colorScheme,
  ) {
    return _buildCardContainer(
      colorScheme: colorScheme,
      children: [
        _buildSwitchTile(
          title: 'Download over Wi-Fi Only',
          subtitle: 'Prevent cellular data usage for extractions',
          value: settings.wifiOnly,
          onChanged: (v) => settings.setWifiOnly(v),
          colorScheme: colorScheme,
        ),
        _buildDivider(colorScheme),
        _buildSwitchTile(
          title: 'Background Downloads',
          subtitle: 'Continue processing when app is minimized',
          value: settings.backgroundDownload,
          onChanged: (v) => settings.setBackgroundDownload(v),
          colorScheme: colorScheme,
        ),
        _buildDivider(colorScheme),
        _buildDropdownTile(
          title: 'Concurrent Downloads',
          subtitle: 'Maximum number of active downloads',
          value: '${settings.concurrentDownloads}',
          items: ['1', '2', '3', '5'],
          onChanged: (v) => settings.setConcurrentDownloads(int.parse(v!)),
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(
    BuildContext context,
    SettingsService settings,
    ColorScheme colorScheme,
  ) {
    return _buildCardContainer(
      colorScheme: colorScheme,
      children: [
        _buildSwitchTile(
          title: 'Enable Notifications',
          subtitle: 'Alert when processing completes',
          value: settings.enableNotifications,
          onChanged: (v) => settings.setEnableNotifications(v),
          colorScheme: colorScheme,
        ),
        _buildDivider(colorScheme),
        _buildSwitchTile(
          title: 'Battery Saver Mode',
          subtitle: 'Pause downloads when battery drops below 15%',
          value: settings.batterySaver,
          onChanged: (v) => settings.setBatterySaver(v),
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _buildGeneralSection(
    BuildContext context,
    SettingsService settings,
    ColorScheme colorScheme,
  ) {
    return _buildCardContainer(
      colorScheme: colorScheme,
      children: [
        _buildIconTile(
          icon: Icons.folder_open,
          title: 'Download Path',
          subtitle: settings.downloadPath,
          colorScheme: colorScheme,
          onTap: () async {
            try {
              String? selectedDirectory = await FilePicker.platform
                  .getDirectoryPath(dialogTitle: 'Select Download Folder');
              if (selectedDirectory != null) {
                settings.setDownloadPath(selectedDirectory);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to pick directory')),
                );
              }
            }
          },
        ),
        _buildDivider(colorScheme),
        _buildSwitchTile(
          title: 'Auto-Analyze Clipboard',
          subtitle: 'Detect links automatically on launch',
          value: settings.autoAnalyze,
          onChanged: (v) => settings.setAutoAnalyze(v),
          colorScheme: colorScheme,
        ),
        _buildDivider(colorScheme),
        _buildIconTile(
          icon: Icons.delete_outline,
          title: 'Clear App Cache',
          subtitle: '$_cacheSizeStr temporary files',
          iconColor: colorScheme.error,
          colorScheme: colorScheme,
          onTap: _clearCache,
        ),
      ],
    );
  }

  Widget _buildContentPreferencesSection(
    BuildContext context,
    SettingsService settings,
    ColorScheme colorScheme,
  ) {
    return _buildCardContainer(
      colorScheme: colorScheme,
      children: [
        _buildDropdownTile(
          title: 'Audio Quality',
          subtitle: 'Eco / Standard / Pro',
          value: settings.audioQuality,
          items: ['Eco', 'Standard', 'Pro'],
          onChanged: (v) => settings.setAudioQuality(v!),
          colorScheme: colorScheme,
        ),
        _buildDivider(colorScheme),
        _buildDropdownTile(
          title: 'Photo Quality',
          subtitle: 'Original / Optimized / Lite',
          value: settings.photoQuality,
          items: ['Original', 'Optimized', 'Lite'],
          onChanged: (v) => settings.setPhotoQuality(v!),
          colorScheme: colorScheme,
        ),
        _buildDivider(colorScheme),
        _buildSwitchTile(
          title: 'Privacy Mode',
          subtitle: 'Strip EXIF and metadata from media',
          value: settings.privacyMode,
          onChanged: (v) => settings.setPrivacyMode(v),
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 17,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: colorScheme.onPrimaryContainer,
                ),
                isDense: true,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                onChanged: onChanged,
                items: items.map<DropdownMenuItem<String>>((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    SettingsService settings,
    ColorScheme colorScheme,
  ) {
    return _buildCardContainer(
      colorScheme: colorScheme,
      children: [
        _buildIconTile(
          title: settings.isInstagramLoggedIn
              ? 'Instagram Connected'
              : 'Log in to Instagram',
          subtitle: settings.isInstagramLoggedIn
              ? 'Your account is linked for private media'
              : 'Unlock high-quality private extractions',
          showArrow: !settings.isInstagramLoggedIn,
          iconWidget: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: settings.isInstagramLoggedIn
                    ? [
                        colorScheme.primary,
                        colorScheme.primary.withValues(alpha: 0.8),
                      ]
                    : [
                        const Color(0xFFf09433),
                        const Color(0xFFe6683c),
                        const Color(0xFFdc2743),
                        const Color(0xFFcc2366),
                        const Color(0xFFbc1888),
                      ],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              settings.isInstagramLoggedIn
                  ? Icons.check_circle_outline
                  : Icons.camera_alt,
              color: Colors.white,
            ),
          ),
          colorScheme: colorScheme,
          onTap: () {
            if (settings.isInstagramLoggedIn) {
              // Show confirmation dialog or just logout
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Log Out'),
                  content: const Text(
                    'Are you sure you want to log out from Instagram?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        settings.logoutInstagram();
                        Navigator.pop(context);
                      },
                      child: const Text('Log Out'),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InstagramLoginScreen(),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context, ColorScheme colorScheme) {
    return _buildCardContainer(
      colorScheme: colorScheme,
      children: [
        _buildIconTile(
          icon: Icons.code,
          title: 'View on GitHub',
          subtitle: 'Source code & issues',
          showExternal: true,
          colorScheme: colorScheme,
          onTap: () {
            launchUrl(
              Uri.parse('https://github.com/AfiqMech/Snap'),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
        _buildDivider(colorScheme),
        _buildIconTile(
          icon: Icons.gavel,
          title: 'Legal / License',
          subtitle: 'Terms and open source licenses',
          showArrow: true,
          colorScheme: colorScheme,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildIconTile({
    IconData? icon,
    Widget? iconWidget,
    required String title,
    required String subtitle,
    Color? iconColor,
    bool showArrow = false,
    bool showExternal = false,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            if (iconWidget != null)
              iconWidget
            else if (icon != null)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor != null
                      ? iconColor.withValues(alpha: 0.1)
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(icon, color: iconColor ?? colorScheme.primary),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 17,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showArrow)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            if (showExternal)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.open_in_new,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Divider(
      height: 1,
      thickness: 1,
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }

  Widget _buildFooter(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Column(
        children: [
          Text(
            'Snap v1.0.0',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Made By Afiq',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
