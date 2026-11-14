import '../native/swifs_ffi.dart';

/// The signed-in user. Stays "you" until a sign-in screen exists.
const String kCurrentUser = 'you';

/// A failed data call. Network problems are retryable. Server rejections are not.
class DataException implements Exception {
  final String message;
  final bool retryable;

  const DataException(this.message, {this.retryable = false});

  @override
  String toString() => message;
}

/// Minutes to a short label: now, 5m, 2h, 3d.
String formatAge(int minutes) {
  if (minutes < 1) return 'now';
  if (minutes < 60) return '${minutes}m';
  if (minutes < 1440) return '${minutes ~/ 60}h';
  return '${minutes ~/ 1440}d';
}

class LikeResult {
  final bool liked;
  final int count;

  const LikeResult({required this.liked, required this.count});
}

class FeedPost {
  final String id;
  final String user;
  final String caption;
  final int views;
  final int ageMinutes;
  int likes;
  int comments;
  bool liked;
  bool isSaved;
  bool isFollowing;

  FeedPost({
    required this.id,
    required this.user,
    required this.caption,
    required this.views,
    required this.ageMinutes,
    required this.likes,
    required this.comments,
    required this.liked,
    required this.isSaved,
    required this.isFollowing,
  });

  /// Row from the Supabase get_feed() function.
  factory FeedPost.fromRow(Map<String, dynamic> r) => FeedPost(
        id: r['id'].toString(),
        user: r['username'].toString(),
        caption: r['caption']?.toString() ?? '',
        views: (r['views'] as num?)?.toInt() ?? 0,
        ageMinutes: (r['age_minutes'] as num?)?.toInt() ?? 0,
        likes: (r['likes'] as num?)?.toInt() ?? 0,
        comments: (r['comments'] as num?)?.toInt() ?? 0,
        liked: r['liked'] == true,
        isSaved: r['is_saved'] == true,
        isFollowing: r['is_following'] == true,
      );

  /// Ranking score from the C++ core.
  int get score => SwifsScore.feed(likes, comments, views, ageMinutes);

  /// The shape the feed screen reads.
  Map<String, dynamic> toMap() => {
        'id': id,
        'user': user,
        'caption': caption,
        'time': formatAge(ageMinutes),
        'views': views,
        'age_minutes': ageMinutes,
        'likes': likes,
        'comments': comments,
        'liked': liked,
        'isSaved': isSaved,
        'isFollowing': isFollowing,
        'score': score,
      };
}

class CommentModel {
  String id;
  final String? parentId;
  final String user;
  final String text;
  String time;
  int ageMinutes;
  int likes;
  bool liked;
  bool showReplies;
  final List<CommentModel> replies;

  CommentModel({
    required this.id,
    this.parentId,
    required this.user,
    required this.text,
    required this.time,
    this.ageMinutes = 0,
    this.likes = 0,
    this.liked = false,
    this.showReplies = false,
    List<CommentModel>? replies,
  }) : replies = replies ?? [];

  /// Row from the Supabase get_comments() function (flat list, replies have parent_id).
  factory CommentModel.fromRow(Map<String, dynamic> r) {
    final age = (r['age_minutes'] as num?)?.toInt() ?? 0;
    return CommentModel(
      id: r['id'].toString(),
      parentId: r['parent_id']?.toString(),
      user: r['username'].toString(),
      text: r['body'].toString(),
      time: formatAge(age),
      ageMinutes: age,
      likes: (r['likes'] as num?)?.toInt() ?? 0,
      liked: r['liked'] == true,
    );
  }

  /// Ids that start with tmp are not saved yet.
  bool get isPending => id.startsWith('tmp');

  /// Ranking score from the C++ core.
  int get score => SwifsScore.comment(likes, replies.length, ageMinutes);
}

/// Turns a flat list into top-level comments, with each one's replies inside.
List<CommentModel> buildCommentTree(List<CommentModel> flat) {
  final tops = <CommentModel>[];
  final byParent = <String, List<CommentModel>>{};
  for (final c in flat) {
    final parent = c.parentId;
    if (parent == null) {
      tops.add(c);
    } else {
      byParent.putIfAbsent(parent, () => []).add(c);
    }
  }
  for (final t in tops) {
    t.replies.addAll(byParent[t.id] ?? const []);
  }
  return tops;
}
