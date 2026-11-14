import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'social_repository.dart';

/// Real server. Calls the SQL functions in supabase/schema.sql.
/// Needs: flutter pub add supabase_flutter, and Supabase.initialize() in main.dart.
class SupabaseSocialRepository implements SocialRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// Turns Supabase errors into DataException. Server rejections are not retried. Everything else is.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw DataException(e.message, retryable: false);
    } catch (_) {
      throw const DataException('Offline or unreachable', retryable: true);
    }
  }

  Map<String, dynamic> _row(dynamic rows) {
    final list = rows as List<dynamic>;
    if (list.isEmpty) throw const DataException('No data returned');
    return Map<String, dynamic>.from(list.first as Map);
  }

  @override
  Future<List<FeedPost>> fetchFeed() => _guard(() async {
        final rows = await _db.rpc('get_feed') as List<dynamic>;
        return rows.map((r) => FeedPost.fromRow(Map<String, dynamic>.from(r as Map))).toList();
      });

  @override
  Future<LikeResult> setLike(String postId, bool liked) => _guard(() async {
        final row = _row(await _db.rpc('set_like', params: {'p_post_id': postId, 'p_liked': liked}));
        return LikeResult(liked: row['is_liked'] == true, count: (row['like_count'] as num).toInt());
      });

  @override
  Future<bool> setSave(String postId, bool saved) => _guard(() async {
        final row = _row(await _db.rpc('set_save', params: {'p_post_id': postId, 'p_saved': saved}));
        return row['is_saved'] == true;
      });

  @override
  Future<bool> setFollow(String username, bool following) => _guard(() async {
        final row = _row(await _db.rpc('set_follow', params: {'p_username': username, 'p_follow': following}));
        return row['is_following'] == true;
      });

  @override
  Future<List<CommentModel>> fetchComments(String postId) => _guard(() async {
        final rows = await _db.rpc('get_comments', params: {'p_post_id': postId}) as List<dynamic>;
        final flat = rows.map((r) => CommentModel.fromRow(Map<String, dynamic>.from(r as Map))).toList();
        return buildCommentTree(flat);
      });

  @override
  Future<CommentModel> addComment(String postId, String text, {String? parentId}) => _guard(() async {
        final row = _row(await _db.rpc('add_comment', params: {
          'p_post_id': postId,
          'p_body': text,
          'p_parent_id': parentId,
        }));
        return CommentModel.fromRow(row);
      });

  @override
  Future<LikeResult> setCommentLike(String commentId, bool liked) => _guard(() async {
        final row = _row(await _db.rpc('set_comment_like', params: {'p_comment_id': commentId, 'p_liked': liked}));
        return LikeResult(liked: row['is_liked'] == true, count: (row['like_count'] as num).toInt());
      });
}
