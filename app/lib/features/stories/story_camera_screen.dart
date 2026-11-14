import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/data/stories_repository.dart';
import '../../core/theme/swifs_icon.dart';
import 'story_review_screen.dart';

const Color _kPrimary = Color(0xFFFF6B35);
const Color _kInk = Color(0xFF111111);
const Color _kMuted = Color(0xFF8E8E93);

/// Choose a photo for your story: big preview on top, camera and gallery below.
class StoryCameraScreen extends StatefulWidget {
  const StoryCameraScreen({super.key});

  @override
  State<StoryCameraScreen> createState() => _StoryCameraScreenState();
}

class _StoryCameraScreenState extends State<StoryCameraScreen> {
  List<AssetEntity> _assets = [];
  final Map<String, Future<Uint8List?>> _thumbs = {};
  AssetEntity? _selected;
  File? _preview;
  bool _loading = true;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    final state = await PhotoManager.requestPermissionExtend();
    if (!state.isAuth) {
      if (mounted) setState(() {
        _denied = true;
        _loading = false;
      });
      return;
    }
    final paths = await PhotoManager.getAssetPathList(type: RequestType.common, onlyAll: true);
    final list = paths.isEmpty ? <AssetEntity>[] : await paths.first.getAssetListPaged(page: 0, size: 120);
    if (!mounted) return;
    setState(() {
      _assets = list;
      _selected = list.isEmpty ? null : list.first;
      _loading = false;
    });
    if (_selected != null) _loadPreview(_selected!);
  }

  Future<void> _loadPreview(AssetEntity asset) async {
    final file = await asset.originFile;
    if (mounted && file != null) setState(() => _preview = file);
  }

  Future<Uint8List?> _thumb(AssetEntity a) =>
      _thumbs.putIfAbsent(a.id, () => a.thumbnailDataWithSize(const ThumbnailSize.square(220)));

  void _pickAsset(AssetEntity a) {
    setState(() => _selected = a);
    _loadPreview(a);
  }

  Future<void> _takePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 92);
    if (x == null || !mounted) return;
    _openReview(File(x.path));
  }

  Future<void> _next() async {
    final asset = _selected;
    if (asset == null) return;
    final file = await asset.originFile;
    if (file == null || !mounted) return;
    if (asset.type == AssetType.video) {
      // Videos skip the photo editor. They upload in the background, like a photo story.
      if (asset.duration > 15) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video stories can be up to 15 seconds.')),
        );
        return;
      }
      StoriesRepository.instance.startUpload(photo: file, layers: const [], isVideo: true);
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    _openReview(file);
  }

  void _openReview(File file) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StoryReviewScreen(photo: file)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const SwifsIcon(LucideIcons.x, color: _kInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New story', style: TextStyle(color: _kInk, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: _selected == null ? null : _next,
            child: Text(
              'Next',
              style: TextStyle(
                color: _selected == null ? _kMuted : _kPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }
    if (_denied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Allow photo access so you can pick photos for your story.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kMuted, fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
                onPressed: () => PhotoManager.openSetting(),
                child: const Text('Open settings'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _takePhoto, child: const Text('Take a photo instead')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Preview of the chosen photo
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            color: const Color(0xFFF0F2F5),
            child: _preview == null
                ? const SizedBox.shrink()
                : Image.file(_preview!, fit: BoxFit.cover),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: const [
              Text('Recents', style: TextStyle(color: _kInk, fontWeight: FontWeight.w600, fontSize: 15)),
              SizedBox(width: 4),
              Icon(Icons.expand_more, color: _kInk, size: 18),
            ],
          ),
        ),
        // Camera tile + gallery grid
        Expanded(
          flex: 6,
          child: GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: _assets.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return GestureDetector(
                  onTap: _takePhoto,
                  child: Container(
                    color: const Color(0xFFF0F2F5),
                    child: const Center(child: SwifsIcon(LucideIcons.camera, color: _kInk, size: 26)),
                  ),
                );
              }
              final asset = _assets[i - 1];
              final picked = _selected?.id == asset.id;
              return GestureDetector(
                onTap: () => _pickAsset(asset),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FutureBuilder<Uint8List?>(
                      future: _thumb(asset),
                      builder: (_, snap) => snap.data == null
                          ? Container(color: const Color(0xFFF0F2F5))
                          : Image.memory(snap.data!, fit: BoxFit.cover),
                    ),
                    if (picked)
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: _kPrimary, width: 3)),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
