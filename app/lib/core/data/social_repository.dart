import 'dart:io';

import 'models.dart';

/// Everything the app needs from the server. Screens only talk to this.
///
/// "cached..." reads come from the phone and return at once (null if nothing is cached).
/// "fetch...", "search..." and "suggested..." reads ask the server.
/// Writes take the desired state (liked = true), so a retry still ends in the right state.
abstract class SocialRepository {
  // Find
  Future<List<Map<String, dynamic>>> suggestedUsers();
  Future<List<Map<String, dynamic>>> searchUsers(String query);
  Future<List<String>> fetchTrendingTags();
  Future<List<Map<String, dynamic>>> fetchTrendingWithUses();
  Future<List<FeedPost>> fetchExplorePosts();
  Future<List<Map<String, dynamic>>> fetchPostMedia(String postId);
  Future<List<FeedPost>> fetchHashtagPosts(String tag);

  // Profile
  Future<Map<String, dynamic>> fetchMyProfile();
  Future<Map<String, dynamic>?> cachedMyProfile();
  Future<List<FeedPost>> fetchMyPosts();
  Future<List<FeedPost>> fetchSavedPosts();

  // Feed
  Future<List<FeedPost>?> cachedFeed();
  Future<List<FeedPost>> fetchFeed();
  /// One post with its author and media, for shared-post previews.
  Future<FeedPost?> fetchPostPreview(String postId);
  /// One page, newest first. Pass [before] (created_at of the last post shown) for the next page.
  Future<List<FeedPost>> fetchFeedPage({DateTime? before, int limit = 10});

  // Comments
  Future<List<CommentModel>?> cachedComments(String postId);
  Future<List<CommentModel>> fetchComments(String postId);

  // Writes
  Future<LikeResult> setLike(String postId, bool liked);
  Future<bool> setSave(String postId, bool saved);
  Future<bool> setFollow(String authorId, bool following);
  Future<CommentModel> addComment(String postId, String text, {String? parentId, String? tempId});
  Future<LikeResult> setCommentLike(String commentId, bool liked);
  Future<void> createPost(String caption, List<Map<String, dynamic>> media);
  Future<List<StoryViewerModel>> fetchStoryViewers(String storyId);

  /// Runs one action from the outbox.
  Future<dynamic> run(OutboxOp op);

  Future<List<NotificationModel>> fetchNotifications();
  /// Deletes every notification for the signed-in user, then checks that none remain.
  Future<void> deleteAllNotifications();
  Future<Map<String, dynamic>> fetchUserProfile(String userId);
  Future<List<FeedPost>> fetchUserPosts(String userId);
  Future<void> blockUser(String userId);

  // Profile
  Future<Map<String, dynamic>> updateMyProfile({String? displayName, String? bio});
  Future<String> uploadMyAvatar(File file);
  Future<Map<String, Map<String, int>>> fetchPostCounts(List<String> postIds);
  Future<void> restrictUser(String userId);

}


