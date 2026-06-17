import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/camera/camera_screen.dart';
import 'features/photo_album/photo_album_screen.dart';
import 'l10n/generated/app_localizations.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const CameraScreen()),
    GoRoute(path: '/album', builder: (context, state) => const PhotoAlbumScreen()),
  ],
);

class EasyBeautyCamApp extends StatelessWidget {
  const EasyBeautyCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EasyBeautyCam',
      theme: AppTheme.lightTheme,

      // ── i18n 接线 ─────────────────────────────────────
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // 当前默认中文；要跟随系统改用 [Locale('en')], [Locale('zh')] 等
      locale: const Locale('zh'),

      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
