import 'models.dart';
import 'social_repository.dart';

/// Sample data that behaves like the server, kept in memory. Used while designing.
class MockSocialRepository implements SocialRepository {

  /// How long each call takes, so loading states can be seen.
  final Duration latency;

  /// Set to true to test offline retries.
  static bool simulateOffline = false;

  final List<_MockPost> _posts = [
    _MockPost(id: 'p1', user: 'alex', caption: 'Chasing sunsets 🌅 #swifs', views: 1200, ageMinutes: 120, baseLikes: 124),
    _MockPost(id: 'p2', user: 'mia', caption: 'Coffee & code ☕️💻', views: 800, ageMinutes: 300, baseLikes: 89),
  ];
  final Map<String, Set<String>> _postLikes = {};
  final Map<String, Set<String>> _saves = {};
  final Map<String, Set<String>> _follows = {};
  final List<_MockComment> _comments = [];
  int _seq = 100;

  MockSocialRepository({this.latency = const Duration(milliseconds: 250)}) {
    final now = DateTime.now();
    _comments.addAll([
      _MockComment('c1', null, 'p1', 'mia', 'Love this vibe 🔥', now.subtract(const Duration(minutes: 120)), {'alex', 'leo'}),
      _MockComment('r1', 'c1', 'p1', 'alex', 'Right? What song is this?', now.subtract(const Duration(minutes: 60)), {}),
      _MockComment('r2', 'c1', 'p1', 'leo', 'Same, I need this playlist', now.subtract(const Duration(minutes: 50)), {'mia'}),
      _MockComment('c2', null, 'p1', 'zara', 'Where was this taken?', now.subtract(const Duration(minutes: 300)), {}),
      _MockComment('c3', null, 'p2', 'leo', 'Follow me back please 🙌', now.subtract(const Duration(minutes: 480)), {}),
      _MockComment('r3', 'c3', 'p2', 'mia', 'Done!', now.subtract(const Duration(minutes: 420)), {}),
    ]);
  }

  Future<void> _network() async {
    await Future.delayed(latency);
    if (simulateOffline) {
      throw const DataException('Offline (simulated)', retryable: true);
    }
  }

  _MockPost _post(String id) {
    for (final p in _posts) {
      if (p.id == id) return p;
    }
    throw const DataException('Post not found');
  }

  _MockComment? _comment(String id) {
    for (final c in _comments) {
      if (c.id == id) return c;
    }
    return null;
  }

  FeedPost _feedFor(_MockPost p) {
    final likers = _postLikes[p.id] ?? <String>{};
    return FeedPost(
      id: p.id,
      user: p.user,
      caption: p.caption,
      views: p.views,
      ageMinutes: p.ageMinutes,
      likes: p.baseLikes + likers.length,
      comments: _comments.where((c) => c.postId == p.id).length,
      liked: likers.contains(kCurrentUser),
      isSaved: (_saves[p.id] ?? <String>{}).contains(kCurrentUser),
      isFollowing: (_follows[kCurrentUser] ?? <String>{}).contains(p.user),
    );
  }

  @override
  Future<List<FeedPost>> fetchFeed() async {
    await _network();
    return [for (final p in _posts) _feedFor(p)];
  }

  @override
  Future<LikeResult> setLike(String postId, bool liked) async {
    await _network();
    final post = _post(postId);
    final likers = _postLikes.putIfAbsent(postId, () => <String>{});
    if (liked) {
      likers.add(kCurrentUser);
    } else {
      likers.remove(kCurrentUser);
    }
    return LikeResult(liked: likers.contains(kCurrentUser), count: post.baseLikes + likers.length);
  }

  @override
  Future<bool> setSave(String postId, bool saved) async {
    await _network();
    _post(postId);
    final set = _saves.putIfAbsent(postId, () => <String>{});
    if (saved) {
      set.add(kCurrentUser);
    } else {
      set.remove(kCurrentUser);
    }
    return set.contains(kCurrentUser);
  }

  @override
  Future<bool> setFollow(String username, bool following) async {
    await _network();
    if (username == kCurrentUser) {
      throw const DataException("You can't follow yourself");
    }
    if (!_posts.any((p) => p.user == username)) {
      throw const DataException('User not found');
    }
    final set = _follows.putIfAbsent(kCurrentUser, () => <String>{});
    if (following) {
      set.add(username);
    } else {
      set.remove(username);
    }
    return set.contains(username);
  }

  @override
  Future<List<CommentModel>> fetchComments(String postId) async {
    await _network();
    _post(postId);
    final now = DateTime.now();
    final flat = [
      for (final c in _comments.where((c) => c.postId == postId))
        CommentModel(
          id: c.id,
          parentId: c.parentId,
          user: c.user,
          text: c.text,
          time: formatAge(_minutesSince(c.created, now)),
          ageMinutes: _minutesSince(c.created, now),
          likes: c.likers.length,
          liked: c.likers.contains(kCurrentUser),
        ),
    ];
    return buildCommentTree(flat);
  }

  @override
  Future<CommentModel> addComment(String postId, String text, {String? parentId}) async {
    await _network();
    _post(postId);
    if (parentId != null) {
      final parent = _comment(parentId);
      if (parent == null || parent.postId != postId) {
        throw const DataException('Parent comment not found');
      }
      if (parent.parentId != null) {
        throw const DataException('Replies only go one level deep');
      }
    }
    final created = DateTime.now();
    final c = _MockComment('k${++_seq}', parentId, postId, kCurrentUser, text, created, {});
    _comments.add(c);
    return CommentModel(id: c.id, parentId: parentId, user: kCurrentUser, text: text, time: 'now');
  }

  @override
  Future<LikeResult> setCommentLike(String commentId, bool liked) async {
    await _network();
    final c = _comment(commentId);
    if (c == null) {
      throw const DataException('Comment not found');
    }
    if (liked) {
      c.likers.add(kCurrentUser);
    } else {
      c.likers.remove(kCurrentUser);
    }
    return LikeResult(liked: c.likers.contains(kCurrentUser), count: c.likers.length);
  }

  static int _minutesSince(DateTime created, DateTime now) {
    final m = now.difference(created).inMinutes;
    return m < 0 ? 0 : m;
  }
}

class _MockPost {
  final String id;
  final String user;
  final String caption;
  final int views;
  final int ageMinutes;
  final int baseLikes;

  _MockPost({
    required this.id,
    required this.user,
    required this.caption,
    required this.views,
    required this.ageMinutes,
    required this.baseLikes,
  });
}

class _MockComment {
  final String id;
  final String? parentId;
  final String postId;
  final String user;
  final String text;
  final DateTime created;
  final Set<String> likers;

  _MockComment(this.id, this.parentId, this.postId, this.user, this.text, this.created, this.likers);
}
