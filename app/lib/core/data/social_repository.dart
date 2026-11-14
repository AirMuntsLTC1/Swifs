import 'models.dart';

/// Everything the app needs from the server. Screens only talk to this.
/// MockSocialRepository runs now (sample data). SupabaseSocialRepository runs after you connect Supabase.
///
/// Writes take the desired state (liked = true), not a toggle, so a retried or replaced request still ends in the right state.
abstract class SocialRepository {
  Future<List<FeedPost>> fetchFeed();
  Future<LikeResult> setLike(String postId, bool liked);
  Future<bool> setSave(String postId, bool saved);
  Future<bool> setFollow(String username, bool following);

  Future<List<CommentModel>> fetchComments(String postId);
  Future<CommentModel> addComment(String postId, String text, {String? parentId});
  Future<LikeResult> setCommentLike(String commentId, bool liked);
}
