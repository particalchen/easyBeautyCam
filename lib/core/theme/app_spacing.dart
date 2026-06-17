import 'package:flutter/widgets.dart';

/// 间距 token —— 与 DESIGN.md spacing.* 一一对应
class AppSpacing {
  AppSpacing._();

  /// 通用主边距
  static const double marginMain = 20;

  /// 小间距（图标/标签之间的紧凑 gap）
  static const double sm = 8;

  /// 栅格间距
  static const double gutterGrid = 12;

  /// 拇指热区最小尺寸（44pt Apple HIG）
  static const double thumbHotzone = 44;

  /// 快门按钮
  static const double shutterSize = 70;

  /// 姿势缩略图
  static const double poseThumbnail = 80;

  /// 相机控制按钮直径（圆环+边框+图标）
  static const double cameraButtonSize = 56;

  // ── 常用边距 preset（基于 marginMain）─────────────────
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: marginMain);
  static const EdgeInsets screenPaddingAll = EdgeInsets.all(marginMain);

  // ── 安全区工具：顶部刘海 / 灵动岛 ─────────────────────
  /// 取顶部安全高度（含 status bar + 灵动岛）
  static double topSafeArea(BuildContext context) =>
      MediaQuery.of(context).padding.top;

  /// 取底部安全高度（home indicator）
  static double bottomSafeArea(BuildContext context) =>
      MediaQuery.of(context).padding.bottom;
}
