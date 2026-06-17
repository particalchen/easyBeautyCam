import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';

/// 相机 AppBar 菜单 BottomSheet
///
/// 视觉：DESIGN.md Elevation & Depth › Floating Panels
/// - 半透暖白底（overlayBg）
/// - 顶部 24pt 圆角
/// - 顶部把手（4pt 灰条）
/// - 菜单项 ListTile（icon + 标题）
class AppMenuSheet extends StatelessWidget {
  final VoidCallback? onPoseLibrary;
  final VoidCallback? onSettings;
  final VoidCallback? onAbout;

  const AppMenuSheet({
    super.key,
    this.onPoseLibrary,
    this.onSettings,
    this.onAbout,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.overlayBg,
      borderRadius: AppRadii.sheetTop,
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: AppRadii.sheetTop,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 顶部把手 ──
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
              ),
              // ── 标题 ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMain,
                  vertical: AppSpacing.gutterGrid,
                ),
                child: Row(
                  children: [
                    Text(l10n.menuTitle, style: AppTypography.headlineMd),
                  ],
                ),
              ),
              // ── 菜单项 ──
              _MenuTile(
                icon: Icons.collections_bookmark_outlined,
                label: l10n.menuPoseLibrary,
                onTap: onPoseLibrary,
              ),
              _MenuTile(
                icon: Icons.settings_outlined,
                label: l10n.menuSettings,
                onTap: onSettings,
              ),
              _MenuTile(
                icon: Icons.info_outline,
                label: l10n.menuAbout,
                onTap: onAbout,
              ),
              const SizedBox(height: AppSpacing.gutterGrid),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.onSurface),
      title: Text(
        label,
        style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
      ),
      onTap: onTap,
    );
  }
}
