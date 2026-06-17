import 'package:flutter/widgets.dart';

/// 圆角 token —— 与 DESIGN.md rounded.* 一一对应
class AppRadii {
  AppRadii._();

  static const double sm = 4;      // 0.25rem
  static const double md = 8;      // 0.5rem (DEFAULT)
  static const double lg = 12;     // 0.75rem
  static const double xl = 16;     // 1rem
  static const double xxl = 24;    // 1.5rem
  static const double full = 9999; // pill / 圆形

  // ── 常用 BorderRadius preset ─────────────────────────
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));

  // 浮层顶部圆角
  static const BorderRadius sheetTop =
      BorderRadius.vertical(top: Radius.circular(xxl));

  // 缩略图卡片
  static const BorderRadius thumbnail = BorderRadius.all(Radius.circular(xl));
}
