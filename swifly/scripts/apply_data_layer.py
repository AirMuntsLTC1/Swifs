#!/usr/bin/env python3
"""Moves the feed onto the data layer (social.dart) and removes the PHP connection.

Run from your project root:  python3 scripts/apply_data_layer.py

Works on your home_screen.dart whether or not apply_backend.py ran before.
Your design and layout are not changed; only the data code is replaced.
Safe to run twice.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HOME = ROOT / 'app' / 'lib' / 'features' / 'home' / 'home_screen.dart'

HANDLERS = '''  Map<String, dynamic>? _findPost(String id) {
    for (final post in _posts) {
      if (post['id'] == id) return post;
    }
    return null;
  }

  void _rescore(Map<String, dynamic> post) {
    post['score'] = SwifsScore.feed(
      (post['likes'] as num).toInt(),
      (post['comments'] as num).toInt(),
      (post['views'] as num).toInt(),
      (post['age_minutes'] as num).toInt(),
    );
  }

  void _applyPost(String id, Map<String, dynamic> values) {
    final post = _findPost(id);
    if (post == null || !mounted) return;
    setState(() {
      post.addAll(values);
      _rescore(post);
    });
  }

  void _applyFollow(String user, bool following) {
    if (!mounted) return;
    setState(() {
      for (final post in _posts) {
        if (post['user'] == user) post['isFollowing'] = following;
      }
    });
  }

  /// Loads the feed from the data layer (sample data now, Supabase later).
  Future<void> _loadFeed() async {
    try {
      final posts = await social.fetchFeed();
      if (!mounted) return;
      final list = posts.map((p) => p.toMap()).toList()
        ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      setState(() => _posts = list);
    } catch (_) {
      // Keep the current posts if loading fails.
    }
  }

  /// Refreshes counts after the comments sheet closes.
  Future<void> _refreshCounts() async {
    try {
      final posts = await social.fetchFeed();
      if (!mounted) return;
      final fresh = {for (final p in posts) p.id: p};
      setState(() {
        for (final post in _posts) {
          final f = fresh[post['id']];
          if (f == null) continue;
          post['comments'] = f.comments;
          post['likes'] = f.likes;
          _rescore(post);
        }
      });
    } catch (_) {}
  }

  Future<void> _openComments(String postId) async {
    await showCommentsSheet(context, postId: postId);
    _refreshCounts();
  }

  void _handleLike(int index) {
    final post = _posts[index];
    final id = post['id'] as String;
    final wasLiked = post['liked'] == true;
    final prevLikes = (post['likes'] as num).toInt();
    final prevScore = post['score'];
    final nowLiked = !wasLiked;
    if (nowLiked) _playPopSound();

    setState(() {
      post['liked'] = nowLiked;
      post['likes'] = prevLikes + (nowLiked ? 1 : -1);
      _rescore(post);
    });

    InteractionQueue.instance.enqueue<LikeResult>(
      'like:$id',
      () => social.setLike(id, nowLiked),
      onSuccess: (r) => _applyPost(id, {'liked': r.liked, 'likes': r.count}),
      onFail: (_) => _applyPost(id, {'liked': wasLiked, 'likes': prevLikes, 'score': prevScore}),
    );
  }

  void _handleSave(int index) {
    final post = _posts[index];
    final id = post['id'] as String;
    final wasSaved = post['isSaved'] == true;
    final nowSaved = !wasSaved;
    if (nowSaved) _playPopSound();
    setState(() => post['isSaved'] = nowSaved);

    InteractionQueue.instance.enqueue<bool>(
      'save:$id',
      () => social.setSave(id, nowSaved),
      onSuccess: (saved) => _applyPost(id, {'isSaved': saved}),
      onFail: (_) => _applyPost(id, {'isSaved': wasSaved}),
    );
  }

  void _handleFollow(int index) {
    final user = _posts[index]['user'] as String;
    final wasFollowing = _posts[index]['isFollowing'] == true;
    final nowFollowing = !wasFollowing;
    _applyFollow(user, nowFollowing);

    InteractionQueue.instance.enqueue<bool>(
      'follow:$user',
      () => social.setFollow(user, nowFollowing),
      onSuccess: (f) => _applyFollow(user, f),
      onFail: (_) => _applyFollow(user, wasFollowing),
    );
  }

'''


def main() -> None:
    src = HOME.read_text(encoding='utf-8')

    if 'social.fetchFeed()' in src:
        print('Already applied. Nothing to do.')
        return

    # 1. Imports: drop the PHP client, add the data layer and queue
    src = re.sub(r"import '\.\./\.\./core/network/swifs_api\.dart';\n", '', src)
    src = re.sub(r"import '\.\./\.\./core/network/interaction_queue\.dart';\n", '', src)
    src = re.sub(r"import '\.\./\.\./core/data/[a-z_]+\.dart';\n", '', src)
    new_imports = [
        "import '../../core/data/social.dart';",
        "import '../../core/data/models.dart';",
        "import '../../core/network/interaction_queue.dart';",
    ]
    if 'comments_sheet.dart' not in src:
        new_imports.append("import '../comments/comments_sheet.dart';")
    anchor = "import '../../core/native/swifs_ffi.dart';"
    assert src.count(anchor) == 1, 'swifs_ffi import not found in home_screen.dart'
    src = src.replace(anchor, anchor + '\n' + '\n'.join(new_imports), 1)

    # 2. Replace the feed logic. Start at _findPost (if present) or the first handler.
    starts = [i for i in (src.find('  Map<String, dynamic>? _findPost('),
                          src.find('  void _handleLike(int index) {')) if i != -1]
    assert starts, 'could not find the feed handlers in home_screen.dart'
    start = min(starts)
    end = src.index('  @override\n  Widget build(BuildContext context) {', start)
    src = src[:start] + HANDLERS + src[end:]

    # 3. Load the feed when the screen opens
    init_line = "    _audioPlayer.setSource(AssetSource('sounds/bubble_pop.mp3'));\n"
    if '_loadFeed();' not in src:
        assert src.count(init_line) == 1, 'initState audio line not found'
        src = src.replace(init_line, init_line + '    _loadFeed();\n', 1)

    # 4. Comment button: open the sheet through _openComments (any previous form)
    pattern = re.compile(
        r"(icon: LucideIcons\.messageCircle,\s*isActive: false,\s*activeColor: Colors\.black,\s*)"
        r"onTap: (?:\(\) \{\}|\(\) => showCommentsSheet\(context, postId: p\['id'\]\)|\(\) async \{.*?\n\s*\}),",
        re.S,
    )
    found = len(pattern.findall(src))
    assert found == 1, f'comment button found {found} times, expected 1'
    src = pattern.sub(lambda m: m.group(1) + "onTap: () => _openComments(p['id']),", src)

    # 5. Remove the old PHP client file if it is still there
    leftover = [ROOT / 'app/lib/core/network/swifs_api.dart', ROOT / 'app/lib/core/config/api_config.dart']
    for f in leftover:
        if f.exists():
            f.unlink()
            print('removed', f.relative_to(ROOT))

    # 6. Remove the old server address constant (no longer used)
    src = re.sub(r"const String apiUrl = [^\n]*\n", '', src)

    HOME.write_text(src, encoding='utf-8')
    print('Feed now uses the data layer (sample data until Supabase is connected).')


if __name__ == '__main__':
    sys.exit(main())


