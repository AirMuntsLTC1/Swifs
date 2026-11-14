import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/data/stories_repository.dart';
import '../../core/theme/swifs_icon.dart';
import 'story_layer_view.dart';

const Color _kPrimary = Color(0xFFFF6B35);
const Color _kInk = Color(0xFF111111);
const Color _kMuted = Color(0xFF8E8E93);

const List<int> _kTextColors = [
  0xFFFFFFFF,
  0xFF111111,
  0xFFFF6B35,
  0xFFFFD60A,
  0xFF34C759,
  0xFF64D2FF,
];

const List<String> _kStickers = ['❤️', '🔥', '😂', '😮', '😢', '👏', '🎉', '⭐', '🥳', '😍', '💯', '✨'];

/// Edit a story photo, then share it. Sharing runs in the background and the home ring fills.
class StoryReviewScreen extends StatefulWidget {
  final File photo;

  const StoryReviewScreen({super.key, required this.photo});

  @override
  State<StoryReviewScreen> createState() => _StoryReviewScreenState();
}

class _StoryReviewScreenState extends State<StoryReviewScreen> {
  final List<StoryLayer> _layers = [];
  int? _selected;

  void _deselect() => setState(() => _selected = null);

  void _removeSelected() {
    final i = _selected;
    if (i == null) return;
    setState(() {
      _layers.removeAt(i);
      _selected = null;
    });
  }

  Future<void> _addText({int? editIndex}) async {
    final existing = editIndex == null ? null : _layers[editIndex];
    final controller = TextEditingController(text: existing?.value ?? '');
    int color = existing?.color ?? _kTextColors.first;

    final result = await showModalBottomSheet<_TextResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                minLines: 1,
                style: TextStyle(color: Color(color), fontSize: 22, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(hintText: 'Type something', border: InputBorder.none),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final c in _kTextColors)
                    GestureDetector(
                      onTap: () => setSheet(() => color = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color == c ? _kPrimary : const Color(0xFFD0D3D9),
                            width: color == c ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 0),
                onPressed: () {
                  final text = controller.text.trim();
                  Navigator.pop(ctx, text.isEmpty ? null : _TextResult(text, color));
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;

    setState(() {
      if (editIndex == null) {
        _layers.add(StoryLayer(kind: 'text', value: result.text, color: result.color, x: 0.5, y: 0.42));
        _selected = _layers.length - 1;
      } else {
        final l = _layers[editIndex].copy()
          ..value = result.text
          ..color = result.color;
        _layers[editIndex] = l;
      }
    });
  }

  Future<void> _openStickers() async {
    final location = TextEditingController();
    final choice = await showModalBottomSheet<_StickerResult>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Location', style: TextStyle(color: _kInk, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: location,
                    decoration: InputDecoration(
                      hintText: 'City, barangay or place',
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF0F2F5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 0),
                  onPressed: () {
                    final v = location.text.trim();
                    if (v.isNotEmpty) Navigator.pop(ctx, _StickerResult.location(v));
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Stickers', style: TextStyle(color: _kInk, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final e in _kStickers)
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, _StickerResult.sticker(e)),
                    child: Center(child: AnimatedSticker(emoji: e, size: 40)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    location.dispose();
    if (choice == null || !mounted) return;
    setState(() {
      _layers.add(StoryLayer(
        kind: choice.kind,
        value: choice.value,
        x: 0.5,
        y: choice.kind == 'location' ? 0.85 : 0.5,
      ));
      _selected = _layers.length - 1;
    });
  }

  void _share() {
    if (StoriesRepository.uploadProgress.value != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still sharing your last story. Try again in a moment.')),
      );
      return;
    }
    StoriesRepository.instance.startUpload(photo: widget.photo, layers: _layers);
    // Back to home, where the profile ring fills while the story uploads.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final selectedLayer = _selected != null ? _layers[_selected!] : null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top tools
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const SwifsIcon(LucideIcons.arrowLeft, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (selectedLayer != null)
                    IconButton(
                      tooltip: 'Delete',
                      icon: const SwifsIcon(LucideIcons.trash2, color: Colors.white),
                      onPressed: _removeSelected,
                    ),
                  if (selectedLayer != null && selectedLayer.kind == 'text')
                    IconButton(
                      tooltip: 'Edit text',
                      icon: const SwifsIcon(LucideIcons.pencil, color: Colors.white),
                      onPressed: () => _addText(editIndex: _selected),
                    ),
                  IconButton(
                    tooltip: 'Add text',
                    icon: const SwifsIcon(LucideIcons.type, color: Colors.white),
                    onPressed: () => _addText(),
                  ),
                  IconButton(
                    tooltip: 'Stickers',
                    icon: const SwifsIcon(LucideIcons.smile, color: Colors.white),
                    onPressed: _openStickers,
                  ),
                ],
              ),
            ),
            // Canvas
            Expanded(
              child: Center(
                child: StoryCanvas(
                  image: FileImage(widget.photo),
                  layers: _layers,
                  editable: true,
                  selected: _selected,
                  onSelect: (i) => setState(() => _selected = i),
                  onChanged: (i, l) => setState(() => _layers[i] = l),
                  onBackgroundTap: _deselect,
                ),
              ),
            ),
            // Share
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your story · visible for 24 hours',
                      style: TextStyle(color: _kMuted, fontSize: 13),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: _share,
                    child: const Text('Share to story', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextResult {
  final String text;
  final int color;
  const _TextResult(this.text, this.color);
}

class _StickerResult {
  final String kind;
  final String value;
  const _StickerResult(this.kind, this.value);
  factory _StickerResult.sticker(String e) => _StickerResult('sticker', e);
  factory _StickerResult.location(String v) => _StickerResult('location', v);
}
