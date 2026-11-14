import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/data/models.dart';
import '../../core/data/stories_repository.dart';
import '../../core/theme/swifs_icon.dart';
import '../../core/widgets/user_avatar.dart';
import 'story_layer_view.dart';

const Color _kPrimary = Color(0xFFFF6B35);

/// Full-screen stories, Facebook style. Tap the left or right side to move, hold to pause.
class StoryViewerScreen extends StatefulWidget {
  final List<StoryGroup> groups;
  final int startGroup;

  const StoryViewerScreen({super.key, required this.groups, required this.startGroup});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> with SingleTickerProviderStateMixin {
  static const _storySeconds = 5;

  late int _g = widget.startGroup;
  int _s = 0;
  int? _viewers;
  final List<int> _hearts = [];
  final TextEditingController _reply = TextEditingController();

  late final AnimationController _timer = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _storySeconds),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });

  StoryGroup get _group => widget.groups[_g];
  StoryItem get _story => _group.stories[_s];

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _timer.dispose();
    _reply.dispose();
    super.dispose();
  }

  /// Starts the current story: records the view and starts the timer.
  void _open() {
    final story = _story;
    _group.viewedIds.add(story.id);
    _viewers = null;
    _timer.forward(from: 0);

    if (_group.isMine) {
      StoriesRepository.instance.viewerCount(story.id).then((n) {
        if (mounted && story.id == _story.id) setState(() => _viewers = n);
      }).catchError((_) {});
    } else {
      StoriesRepository.instance.markViewed(story.id).catchError((_) {});
    }
  }

  void _next() {
    if (!mounted) return;
    if (_s < _group.stories.length - 1) {
      setState(() => _s++);
      _open();
    } else if (_g < widget.groups.length - 1) {
      setState(() {
        _g++;
        _s = 0;
      });
      _open();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (!mounted) return;
    if (_s > 0) {
      setState(() => _s--);
      _open();
    } else if (_g > 0) {
      setState(() {
        _g--;
        _s = 0;
      });
      _open();
    } else {
      _timer.forward(from: 0);
    }
  }

  Future<void> _sendReply() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    final storyId = _story.id;
    _reply.clear();
    FocusScope.of(context).unfocus();
    try {
      await StoriesRepository.instance.reply(storyId, text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't send your reply.")));
      }
    }
  }

  void _heart() {
    final id = DateTime.now().microsecondsSinceEpoch;
    setState(() => _hearts.add(id));
    StoriesRepository.instance.react(_story.id, '❤️').catchError((_) {});
  }

  String _ago(DateTime t) {
    final minutes = DateTime.now().toUtc().difference(t.toUtc()).inMinutes;
    return formatAge(minutes < 0 ? 0 : minutes);
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Story photo and layers, centered on a 9:16 canvas
          Positioned.fill(
            child: Center(
              child: story.photoUrl.isEmpty
                  ? const SizedBox.shrink()
                  : StoryCanvas(
                      image: CachedNetworkImageProvider(story.photoUrl),
                      layers: story.layers,
                    ),
            ),
          ),
          // Tap zones and hold-to-pause, under the header and footer
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => d.localPosition.dx < width / 3 ? _prev() : _next(),
              onLongPressStart: (_) => _timer.stop(),
              onLongPressEnd: (_) => _timer.forward(),
            ),
          ),
          // Floating hearts
          for (final id in _hearts)
            Positioned(
              right: 28,
              bottom: 110,
              child: _FloatingHeart(
                key: ValueKey(id),
                onDone: () {
                  if (mounted) setState(() => _hearts.remove(id));
                },
              ),
            ),
          // Header: progress bars, author, close
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Row(
                    children: [
                      for (var i = 0; i < _group.stories.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedBuilder(
                              animation: _timer,
                              builder: (_, __) => LinearProgressIndicator(
                                minHeight: 2.5,
                                value: i < _s ? 1 : (i == _s ? _timer.value : 0),
                                backgroundColor: Colors.white30,
                                valueColor: const AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
                  child: Row(
                    children: [
                      UserAvatar(url: _group.avatarUrl, name: _group.label, radius: 17),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _group.isMine ? 'Your story' : _group.label,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            Text(
                              _ago(story.createdAt),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const SwifsIcon(LucideIcons.x, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Footer: viewers for my story, reply box for everyone else's
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: _group.isMine
                    ? Row(
                        children: [
                          const SwifsIcon(LucideIcons.eye, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _viewers == null ? 'Viewers…' : '$_viewers ${_viewers == 1 ? 'viewer' : 'viewers'}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _reply,
                              onTap: () => _timer.stop(),
                              onSubmitted: (_) {
                                _timer.forward();
                                _sendReply();
                              },
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Send a reply…',
                                hintStyle: const TextStyle(color: Colors.white70),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white12,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(color: Colors.white38),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite, color: _kPrimary),
                            onPressed: _heart,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A heart that floats up and fades out, then removes itself.
class _FloatingHeart extends StatefulWidget {
  final VoidCallback onDone;

  const _FloatingHeart({super.key, required this.onDone});

  @override
  State<_FloatingHeart> createState() => _FloatingHeartState();
}

class _FloatingHeartState extends State<_FloatingHeart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Transform.translate(
          offset: Offset(0, -180 * t),
          child: Opacity(
            opacity: (1 - t).clamp(0.0, 1.0).toDouble(),
            child: const Icon(Icons.favorite, color: Color(0xFFFF3B5C), size: 36),
          ),
        );
      },
    );
  }
}
