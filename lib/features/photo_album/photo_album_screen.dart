import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';
import 'app_photo_repository.dart';

/// App 内相册 —— 只显示本 app 拍过的照片
///
/// 交互：
/// - 默认模式：点照片 → 全屏预览
/// - 长按 → 进入多选模式（再点其他可选中/取消）
/// - 选中 ≥1 时，AppBar 显示删除按钮 + 选中数
/// - 取消按钮 / 系统返回 → 退出多选模式
class PhotoAlbumScreen extends ConsumerStatefulWidget {
  const PhotoAlbumScreen({super.key});

  @override
  ConsumerState<PhotoAlbumScreen> createState() => _PhotoAlbumScreenState();
}

class _PhotoAlbumScreenState extends ConsumerState<PhotoAlbumScreen> {
  List<String> _photoPaths = [];
  bool _isLoading = true;

  /// 多选模式：true 表示正在选
  bool _selectionMode = false;
  /// 当前选中的路径集合
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    final repo = ref.read(appPhotoRepositoryProvider);
    final paths = await repo.listAll();
    if (mounted) {
      setState(() {
        _photoPaths = paths;
        _isLoading = false;
        _exitSelection();
      });
    }
  }

  void _enterSelection(String path) {
    setState(() {
      _selectionMode = true;
      _selected.add(path);
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  void _toggleSelect(String path) {
    setState(() {
      if (_selected.contains(path)) {
        _selected.remove(path);
        if (_selected.isEmpty) _selectionMode = false;
      } else {
        _selected.add(path);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10nDeleteTitle),
        content: Text(l10nDeleteConfirm(_selected.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10nCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10nDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(appPhotoRepositoryProvider);
    final toDelete = _selected.toList();
    await repo.delete(toDelete);
    await _loadPhotos();
  }

  String get l10nDeleteTitle => '删除照片';
  String get l10nCancel => '取消';
  String get l10nDelete => '删除';
  String l10nDeleteConfirm(int n) => '确定要删除这 $n 张照片吗？此操作不可撤销。';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode) _exitSelection();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: _selectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelection,
                )
              : null,
          title: Text(
            _selectionMode ? '已选 ${_selected.length}' : l10n.cameraAlbum,
          ),
          actions: _selectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _deleteSelected,
                    tooltip: '删除',
                  ),
                ]
              : null,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _photoPaths.isEmpty
                ? _buildEmpty()
                : _buildGrid(),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: AppColors.onSurfaceVariant,
          ),
          SizedBox(height: AppSpacing.gutterGrid),
          Text(
            '还没有拍过照片',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: _photoPaths.length,
      itemBuilder: (context, index) {
        final path = _photoPaths[index];
        final isSelected = _selected.contains(path);
        return _PhotoTile(
          path: path,
          isSelected: isSelected,
          selectionMode: _selectionMode,
          onTap: () {
            if (_selectionMode) {
              _toggleSelect(path);
            } else {
              _openPhoto(path);
            }
          },
          onLongPress: () => _enterSelection(path),
        );
      },
    );
  }

  void _openPhoto(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                child: Center(child: Image.file(File(path))),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单张缩略图 tile
class _PhotoTile extends StatelessWidget {
  final String path;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PhotoTile({
    required this.path,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Image.file(File(path), fit: BoxFit.cover),
          ),
          // 选中描边
          if (isSelected)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.primary, width: 3),
                  ),
                ),
              ),
            ),
          // 选中打钩
          if (selectionMode)
            Positioned(
              top: 6,
              right: 6,
              child: IgnorePointer(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.primary
                        : Colors.black.withValues(alpha: 0.35),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}