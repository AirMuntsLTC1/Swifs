import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/widgets/asset_preview.dart';
import '../../core/theme/swifs_icon.dart';
import '../../core/data/social.dart';

const Color kPrimary = Color(0xFFFF6B35);
const Color kInk = Color(0xFF111111);
const Color kMuted = Color(0xFF8E8E93);

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  List<AssetEntity> _assets = [];
  final Map<String, Future<Uint8List?>> _thumbs = {};
  final List<AssetEntity> _selected = [];
  AssetEntity? _previewAsset;
  bool _loading = true;
  bool _isUploading = false;
  final TextEditingController _captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadGallery() async {
    final state = await PhotoManager.requestPermissionExtend();
    if (!state.isAuth) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common, 
      onlyAll: true,
    );
    final list = paths.isEmpty ? <AssetEntity>[] : await paths.first.getAssetListPaged(page: 0, size: 120);
    if (!mounted) return;
    setState(() {
      _assets = list;
      _loading = false;
    });
  }

  Future<Uint8List?> _thumb(AssetEntity a) =>
      _thumbs.putIfAbsent(a.id, () => a.thumbnailDataWithSize(const ThumbnailSize.square(200)));

  void _toggleSelect(AssetEntity a) {
    setState(() {
      if (_selected.contains(a)) {
        _selected.remove(a);
      } else {
        if (_selected.length < 10) _selected.add(a);
      }
      _previewAsset = a;
    });
  }

  Future<void> _next() async {
    if (_selected.isEmpty) return;
    // Instead of uploading immediately, we can show a caption view or upload directly.
    // For Instagram style, we usually go to a caption step. Here we'll show a modal for caption.
    setState(() => _isUploading = true);
    try {
      final mediaList = <Map<String, dynamic>>[];
      for (final asset in _selected) {
        final file = await asset.file;
        if (file != null) {
          mediaList.add({
            'path': file.path,
            'type': asset.type == AssetType.video ? 'video' : 'image',
            'width': asset.width,
            'height': asset.height,
          });
        }
      }
      await social.createPost(_captionController.text.trim(), mediaList);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post shared!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const SwifsIcon(LucideIcons.x, color: kInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New post', style: TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _selected.isEmpty || _isUploading ? null : _next,
            child: _isUploading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
                : Text('Next', style: TextStyle(color: _selected.isEmpty ? kMuted : kPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : Column(
              children: [
                // Top: Media Viewer
                Expanded(
                  flex: 5,
                  child: Container(
                    color: const Color(0xFFF0F2F5),
                    child: _previewAsset == null
                        ? const Center(child: Text('Select media', style: TextStyle(color: kMuted)))
                        : AssetPreview(key: ValueKey(_previewAsset!.id), asset: _previewAsset!),
                  ),
                ),
                // Bottom: Gallery Grid
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Recents', style: TextStyle(color: kInk, fontWeight: FontWeight.w600, fontSize: 15)),
                            Text('${_selected.length}/10', style: const TextStyle(color: kMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(2),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 2,
                          ),
                          itemCount: _assets.length,
                          itemBuilder: (_, i) {
                            final asset = _assets[i];
                            final index = _selected.indexOf(asset);
                            final isSelected = index != -1;
                            return GestureDetector(
                              onTap: () => _toggleSelect(asset),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  FutureBuilder<Uint8List?>(
                                    future: _thumb(asset),
                                    builder: (_, snap) => snap.data == null
                                        ? Container(color: const Color(0xFFF0F2F5))
                                        : Image.memory(snap.data!, fit: BoxFit.cover),
                                  ),
                                  if (asset.type == AssetType.video)
                                    const Positioned(
                                      bottom: 4, right: 4,
                                      child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                                    ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? kPrimary : Colors.black26,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: isSelected
                                          ? Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      if (_selected.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: TextField(
                            controller: _captionController,
                            maxLines: 2,
                            minLines: 1,
                            decoration: const InputDecoration(
                              hintText: 'Write a caption...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: kMuted),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
