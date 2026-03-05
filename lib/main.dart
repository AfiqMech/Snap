import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/snap_dashboard.dart';
import 'features/extraction/youtube_dl_extractor.dart';
import 'features/extraction/photo_extractor.dart';
import 'core/services/portal_service.dart';
import 'ui/viewmodel/snap_view_model.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'core/services/settings_service.dart';
import 'core/services/history_service.dart';

import 'core/services/notification_service.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Global error handling for "crashless" experience
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint("Flutter Error caught: ${details.exception}");
      };

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final notificationService = NotificationService();
      await notificationService.init();

      runApp(
        MultiProvider(
          providers: [
            Provider<NotificationService>.value(value: notificationService),
            Provider<PortalService>(create: (_) => PortalService()),
            Provider<YoutubeDLExtractor>(create: (_) => YoutubeDLExtractor()),
            Provider<PhotoExtractor>(create: (_) => PhotoExtractor()),
            ChangeNotifierProvider<SettingsService>(
              create: (_) =>
                  SettingsService()..init(), // Call init to load prefs
            ),
            ChangeNotifierProvider<HistoryService>(
              create: (_) => HistoryService(prefs),
            ),
            ChangeNotifierProvider<SnapViewModel>(
              create: (context) => SnapViewModel(
                context.read<YoutubeDLExtractor>(),
                context.read<PhotoExtractor>(),
                context.read<HistoryService>(),
                context.read<NotificationService>(),
              ),
            ),
          ],
          child: const SnapApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint("Uncaught Zoned Error: $error");
    },
  );
}

class SnapApp extends StatelessWidget {
  const SnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use Selector so only theme-relevant setting changes trigger a rebuild.
    // Previously context.watch rebuilt the entire MaterialApp on EVERY setting
    // change (including Wi-Fi toggle, notifications, etc.) which was causing stutter.
    return Selector<
      SettingsService,
      ({ThemeMode themeMode, bool useDynamicColor, bool useOled})
    >(
      selector: (_, s) => (
        themeMode: s.themeMode,
        useDynamicColor: s.useDynamicColor,
        useOled: s.useOledDarkMode,
      ),
      builder: (context, themeSettings, child) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            ColorScheme lightColorScheme;
            ColorScheme darkColorScheme;

            if (lightDynamic != null &&
                darkDynamic != null &&
                themeSettings.useDynamicColor) {
              lightColorScheme = lightDynamic.harmonized();
              darkColorScheme = darkDynamic.harmonized();
            } else {
              lightColorScheme = ColorScheme.fromSeed(
                seedColor: AppTheme.seedColor,
                brightness: Brightness.light,
              );
              darkColorScheme = ColorScheme.fromSeed(
                seedColor: AppTheme.seedColor,
                brightness: Brightness.dark,
              );
            }

            return MaterialApp(
              title: 'Snap',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.buildTheme(lightColorScheme, isDark: false),
              darkTheme: AppTheme.buildTheme(
                darkColorScheme,
                isDark: true,
                useOled: themeSettings.useOled,
              ),
              themeMode: themeSettings.themeMode,
              // Disable Flutter's AnimatedTheme crossfade — it interpolates
              // every color on every frame for 200ms, causing repaint storms.
              // Instant switch is smoother on all devices.
              themeAnimationDuration: Duration.zero,
              home: child!,
            );
          },
        );
      },
      // SnapDashboard never needs to rebuild due to theme settings, pass as child
      child: const SnapDashboard(),
    );
  }
}
