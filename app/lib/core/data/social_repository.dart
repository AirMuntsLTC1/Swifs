import 'models.dart';

/// Everything the app needs from the server. Screens only talk to this.
///
/// "cached..." reads come from the phone and return at once (null if nothing is cached).
/// "fetch..." reads ask the server and update the cache.
/// Writes take the desired state (liked = true), so a retry still ends in the right state.
abstract class SocialRepository {
  Future<List<Map<String, dynamic>>> searchUsers(String query);
  Future<List<String>> fetchTrendingTags();

  Future<List<FeedPost>?> cachedFeed();
  Future<List<FeedPost>> fetchFeed();

  Future<List<CommentModel>?> cachedComments(String postId);
  Future<List<CommentModel>> fetchComments(String postId);

  Future<LikeResult> setLike(String postId, bool liked);
  Future<bool> setSave(String postId, bool saved);
  Future<bool> setFollow(String authorId, bool following);
  Future<CommentModel> addComment(String postId, String text, {String? parentId, String? tempId});
  Future<LikeResult> setCommentLike(String commentId, bool liked);

  /// Runs one action from the outbox.
  Future<dynamic> run(OutboxOp op);
}
