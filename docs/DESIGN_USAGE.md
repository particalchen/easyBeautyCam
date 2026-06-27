# EasyBeautyCam · 设计 / i18n 维护指南

> 给未来的自己 / 设计师 / 新成员的速查手册。
> 改设计、加语言、换图，**只动这一两份文件**，不需要翻 widget。

---

## 1. 文件结构（设计相关）

```
DESIGN.md                          # 顶层设计规范（人读，YAML frontmatter + 说明）
docs/design-references/            # 设计师给的 SVG 稿（不打包，仅参考）
lib/
├── core/theme/
│   ├── app_colors.dart            # 颜色 token（DESIGN.md colors.* 镜像）
│   ├── app_typography.dart        # 字号 token（typography.* 镜像）
│   ├── app_spacing.dart           # 间距 token（spacing.* 镜像）
│   ├── app_radii.dart             # 圆角 token（rounded.* 镜像）
│   └── app_theme.dart             # 上面 4 个拼成 ThemeData
├── l10n/
│   ├── app_zh.arb                 # 中文文案（template）
│   ├── app_en.arb                 # 英文文案
│   └── generated/                 # flutter gen-l10n 产物，不要手改
└── features/.../widgets/          # 所有 UI 组件，从 token 拿值
```

## 2. 改一个颜色（最常见操作）

**例：把主色从 `#9F4035` 改成 `#E85A4F`**

1. 打开 `DESIGN.md`，找到 `colors.primary`，改为 `#e85a4f`
2. 打开 `lib/core/theme/app_colors.dart`，把
   ```dart
   static const Color primary = Color(0xFF9F4035);
   ```
   改为
   ```dart
   static const Color primary = Color(0xFFE85A4F);
   ```
3. 如果是渐变色（`primaryGradientStart` / `primaryGradientEnd`），同步改
4. 跑 `flutter run`，完事

> 不用翻任何 widget，因为所有 widget 都引用 `AppColors.primary` 而非硬编码色值。

## 3. 改字号 / 圆角 / 间距

完全同理 —— 改 `DESIGN.md` 对应段，然后改 `app_typography.dart` / `app_radii.dart` / `app_spacing.dart`。

## 4. 加一种新语言

**例：加日语 `ja`**

1. 复制 `lib/l10n/app_en.arb` → `lib/l10n/app_ja.arb`
2. 翻译 `app_ja.arb` 里的 value（保留 key 不动）
3. 把 `lib/l10n/app_ja.arb` 第一行的 `"@@locale": "en"` 改成 `"@@locale": "ja"`
4. 在 `lib/app.dart` 里把 `Locale('ja')` 加到 `supportedLocales`
5. 跑 `flutter gen-l10n`

> 临时只翻译了部分 key 也行，缺失的会回落到 `app_zh.arb` 的内容。

## 5. 改一个文案

**例：把"相册"改成"我的相册"**

1. 打开 `lib/l10n/app_zh.arb`
2. 找到 `"cameraAlbum": "相册"`，改为 `"cameraAlbum": "我的相册"`
3. 跑 `flutter gen-l10n`，完事
4. 不要去 widget 里找 `'相册'` 字符串硬改

## 6. 替换一个图标 / 加 SVG 图标

**例：把"相册"图标从 Material `Icons.photo_library_outlined` 换成自定义 SVG**

1. 把设计师的 SVG 放进 `assets/icons/album.svg`
2. `pubspec.yaml` 里确认 `assets/icons/` 已在 `assets` 列表
3. 在 `lib/core/theme/app_icons.dart`（如果没有就新建）注册：
   ```dart
   class AppIcons {
     static const String album = 'assets/icons/album.svg';
   }
   ```
4. 替换 widget 里的 `Icon(Icons.photo_library_outlined)` 为
   ```dart
   SvgPicture.asset(AppIcons.album, width: 24, height: 24)
   ```

> `pubspec.yaml` 已经声明 `flutter_svg: ^2.0.10`，可直接用。

## 7. 设计师更新了 SVG 设计稿

1. 设计师把新稿扔进 `docs/design-references/`
2. 开发者**只**改 token 文件（`app_colors.dart` 等）+ 必要时微调 widget
3. 旧稿归档（不要直接覆盖，可能要 A/B 比对）

## 8. 重要约定

- **所有 widget 必须 import token 文件**，不允许在 widget 里写 `Color(0xFF...)` / `EdgeInsets.all(20)`
- **所有用户可见的中文 / 英文必须来自 `AppLocalizations.of(context)`**，不允许硬编码
- **新增 widget 默认带 const 构造函数**（提升性能）
- **底部布局必须 `SafeArea(top: false, ...)` 包裹**，避让 home indicator
- **顶部 AppBar 自动避让刘海 / 灵动岛**（Scaffold 默认行为），不要重复 `SafeArea`

## 9. 你需要手动跑的命令

```bash
# 1. 装新依赖
flutter pub get

# 2. 生成 AppLocalizations 类（每次改 ARB 都要跑）
flutter gen-l10n

# 3. 跑起来
flutter run
```

`flutter gen-l10n` 也可以集成进 `pubspec.yaml` 的 hooks，方法是：

```yaml
flutter:
  generate: true   # ← 这个已经开了
```

这样 `flutter pub get` 时会自动跑 `gen-l10n`，不需要手动。

---

## 10. 故障排查

| 现象 | 原因 | 解决 |
|------|------|------|
| `AppLocalizations` import 报错 | 没跑 `flutter gen-l10n` | `flutter pub get` 后 IDE 重启 |
| ARB 改了但文案没变 | 没重新生成 | `flutter gen-l10n` |
| 颜色改完没生效 | widget 里硬编码了色值 | 全局 grep `0xFF` 找残留 |
| 改 SAFEAREA 没效果 | 被外层 SafeArea 重复包裹 | 看 widget tree，只留一个 SafeArea |
