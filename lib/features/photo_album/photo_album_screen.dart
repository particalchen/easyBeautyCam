import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';
import 'photo_album_repository.dart';

class PhotoAlbumScreen extends ConsumerStatefulWidget {
  const PhotoAlbumScreen({super.key});

  @override
  ConsumerState<PhotoAlbumScreen> createState() => _PhotoAlbumScreenState();
}

class _PhotoAlbumScreenState extends ConsumerState<PhotoAlbumScreen> {
  List<String> _photoPaths = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final repo = ref.read(photoAlbumRepositoryProvider);
    final granted = await repo.requestPermission();
    if (!granted) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final paths = await repo.loadRecentPhotoPaths();
    if (mounted) {
      setState(() {
        _photoPaths = paths;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.cameraAlbum),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: _photoPaths.length,
              itemBuilder: (context, index) {
                final path = _photoPaths[index];
                return GestureDetector(
                  onTap: () => _openPhoto(path),
                  child: Image.file(File(path), fit: BoxFit.cover),
                );
              },
            ),
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