import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../cache/local_cache.dart';
import '../media/image_prep.dart';
import 'models.dart';
import 'social_repository.dart';

/// Reads and writes the Supabase tables: posts, post_media, profiles, comments,
/// post_likes, post_saves, follows, comment_likes, trending_tags.
/// Columns for a post row. Every column here must exist in the database (see the migration).
const String _postSelect =
    'id, author_id, text, likes, views, created_at, post_media(kind, storage_path, thumb_path, position, width, height)';

class SupabaseSocialRepository implements SocialRepository {
  final LocalCache _cache = LocalCache.instance;

  SupabaseClient get _db => Supabase.instance.client;

  String get _me {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const DataException('Please sign in.', retryable: true);
    return id;
  }

  /// Turns Supabase errors into DataException. Server rejections are not retried; network errors are.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DataException {
      rethrow;
    } on PostgrestException catch (e) {
      throw DataException(e.message, retryable: false);
    } on StorageException catch (e) {
      throw DataException(e.message, retryable: false);
    } catch (_) {
      throw const DataException("Can't reach the server.", retryable: true);
    }
  }

  int _ageMinutes(Object? createdAt) {
    final t = DateTime.tryParse(createdAt?.toString() ?? '');
    if (t == null) return 0;
    final m = DateTime.now().toUtc().difference(t.toUtc()).inMinutes;
    return m < 0 ? 0 : m;
  }

  String get _mediaBase => _db.rest.url.replaceAll('/rest/v1', '');

  String _publicMediaUrl(String path) => '$_mediaBase/storage/v1/object/public/post-media/$path';

  /// Removes characters that would break a PostgREST filter string.
  String _safeFilter(String q) => q.trim().replaceAll(RegExp(r'[,()%*]'), ' ').trim();

  Future<Map<String, Map<String, dynamic>>> _profilesFor(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _db
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .inFilter('id', ids);
    final map = {for (final r in rows) r['id'].toString(): Map<String, dynamic>.from(r)};
    final cached = (await _cache.read('cache.profiles') as Map?) ?? {};
    await _cache.write('cache.profiles', {...cached, ...map});
    return map;
  }

  /// Adds isFollowing to user rows for the signed-in user.
  Future<List<Map<String, dynamic>>> _withFollowState(List<Map<String, dynamic>> users) async {
    if (users.isEmpty) return users;
    final me = _me;
    final followRows = await _db.from('follows').select('followee').eq('follower', me);
    final following = {for (final r in followRows) r['followee'].toString()};
    for (final u in users) {
      u['isFollowing'] = following.contains(u['id'].toString());
    }
    return users;
  }

  // ------------------------------------------------------------------
  // Find: users, suggestions, trending tags, explore grid
  // ------------------------------------------------------------------

  @override
  Future<List<Map<String, dynamic>>> suggestedUsers() => _guard(() async {
        final me = _me;
        final rows = await _db
            .from('profiles')
            .select('id, username, display_name, avatar_url, followers_count, following_count')
            .neq('id', me)
            .order('followers_count', ascending: false)
            .limit(20);
        final users = rows.map((r) => Map<String, dynamic>.from(r)).toList();
        return _withFollowState(users);
      });

  @override
  Future<List<Map<String, dynamic>>> searchUsers(String query) => _guard(() async {
        final q = _safeFilter(query);
        if (q.isEmpty) return suggestedUsers();
        final me = _me;
        final rows = await _db
            .from('profiles')
            .select('id, username, display_name, avatar_url, followers_count, following_count')
            .or('username.ilike.%$q%,display_name.ilike.%$q%')
            .neq('id', me)
            .limit(20);
        final users = rows.map((r) => Map<String, dynamic>.from(r)).toList();
        return _withFollowState(users);
      });

  @override
  Future<List<String>> fetchTrendingTags() => _guard(() async {
        final rows = await fetchTrendingWithUses();
        return rows.map((r) => r['tag'].toString()).toList();
      });

  @override
  Future<List<Map<String, dynamic>>> fetchTrendingWithUses() => _guard(() async {
        final rows = await _db
            .from('trending_tags')
            .select('tag, uses')
            .order('uses', ascending: false)
            .limit(12);
        return rows.map((r) {
          final tag = r['tag'].toString().replaceFirst('#', '').trim();
          return {'tag': tag, 'uses': (r['uses'] as num?)?.toInt() ?? 0};
        }).where((m) => (m['tag'] as String).isNotEmpty).toList();
      });

  @override
  Future<List<FeedPost>> fetchExplorePosts() => _guard(() async {
        final rows = await _db
            .from('posts')
            .select(_postSelect)
            .order('likes', ascending: false)
            .limit(60);
        final posts = rows.map((e) => Map<String, dynamic>.from(e)).toList();
        final list = await _hydrate(posts);
        // Most liked and most commented first.
        list.sort((a, b) => (b.likes + b.comments).compareTo(a.likes + a.comments));
        return list;
      });

  @override
  Future<List<FeedPost>> fetchHashtagPosts(String tag) => _guard(() async {
        final clean = tag.replaceAll('#', '').trim();
        if (clean.isEmpty) return <FeedPost>[];
        final rows = await _db
            .from('posts')
            .select(_postSelect)
            .ilike('text', '%#$clean%')
            .order('created_at', ascending: false)
            .limit(60);
        final lower = '#${clean.toLowerCase()}';
        final posts = rows
            .map((e) => Map<String, dynamic>.from(e))
            .where((p) => (p['text'] ?? '').toString().toLowerCase().contains(lower))
            .toList();
        return _hydrate(posts);
      });

  // ------------------------------------------------------------------
  // Post Media (for carousel)
  // ------------------------------------------------------------------

  @override
  Future<List<Map<String, dynamic>>> fetchPostMedia(String postId) => _guard(() async {
        final rows = await _db
            .from('post_media')
            .select('kind, storage_path, thumb_path, position')
            .eq('post_id', postId)
            .order('position', ascending: true);
            
        return rows.map((r) {
          final path = r['storage_path']?.toString();
          final thumb = r['thumb_path']?.toString();
          return {
            'type': r['kind']?.toString() ?? 'image',
            'url': path != null ? _publicMediaUrl(path) : null,
            'thumbUrl': thumb != null ? _publicMediaUrl(thumb) : null,
          };
        }).where((m) => m['url'] != null).toList();
      });

  // ------------------------------------------------------------------
  // Profile
  // ------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>> fetchMyProfile() => _guard(() async {
        final me = _me;
        final row = await _db
            .from('profiles')
            .select('id, username, display_name, avatar_url, followers_count, following_count, bio')
            .eq('id', me)
            .maybeSingle();
        final postCount = (await _db.from('posts').select('id').eq('author_id', me)).length;
        final profile = row == null ? <String, dynamic>{'id': me} : Map<String, dynamic>.from(row);
        profile['posts_count'] = postCount;
        await _cache.write('cache.myprofile', profile);
        return profile;
      });

  @override
  Future<Map<String, dynamic>> updateMyProfile({String? displayName, String? bio}) => _guard(() async {
        final me = _me;
        final changes = <String, dynamic>{};
        if (displayName != null) changes['display_name'] = displayName.trim();
        if (bio != null) changes['bio'] = bio.trim();
        if (changes.isNotEmpty) {
          await _db.from('profiles').update(changes).eq('id', me);
        }
        return fetchMyProfile();
      });

  @override
  Future<String> uploadMyAvatar(File file) => _guard(() async {
        final me = _me;
        final ext = file.path.split('.').last.toLowerCase();
        final safeExt = const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ? ext : 'jpg';
        final contentType = safeExt == 'png'
            ? 'image/png'
            : safeExt == 'webp'
                ? 'image/webp'
                : 'image/jpeg';
        // A new file name each time, so the app never shows an old photo from cache.
        final path = '$me/avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
        final bucket = _db.storage.from('avatars');
        await bucket.upload(path, file, fileOptions: FileOptions(contentType: contentType, upsert: true));
        final url = bucket.getPublicUrl(path);
        await _db.from('profiles').update({'avatar_url': url}).eq('id', me);
        return url;
      });

  @override
  Future<Map<String, Map<String, int>>> fetchPostCounts(List<String> postIds) => _guard(() async {
        if (postIds.isEmpty) return <String, Map<String, int>>{};
        final rows = await _db.rpc('post_counts', params: {'p_post_ids': postIds});
        final out = <String, Map<String, int>>{};
        for (final r in (rows as List)) {
          final m = Map<String, dynamic>.from(r as Map);
          out[m['post_id'].toString()] = {
            'likes': (m['likes'] as num?)?.toInt() ?? 0,
            'comments': (m['comments'] as num?)?.toInt() ?? 0,
            'shares': (m['shares'] as num?)?.toInt() ?? 0,
          };
        }
        return out;
      });

  /// Feed counts must still load if the count call fails: fall back to the stored values.
  Future<Map<String, Map<String, int>>> _countsOrEmpty(List<String> postIds) async {
    try {
      return await fetchPostCounts(postIds);
    } catch (_) {
      return <String, Map<String, int>>{};
    }
  }

  @override
  Future<Map<String, dynamic>?> cachedMyProfile() async {
    final raw = await _cache.read('cache.myprofile');
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  @override
  Future<List<FeedPost>> fetchMyPosts() => _guard(() async {
        final me = _me;
        final rows = await _db
            .from('posts')
            .select(_postSelect)
            .eq('author_id', me)
            .order('created_at', ascending: false)
            .limit(60);
        return _hydrate(rows.map((e) => Map<String, dynamic>.from(e)).toList());
      });

  @override
  Future<List<FeedPost>> fetchSavedPosts() => _guard(() async {
        final me = _me;
        final saves = await _db.from('post_saves').select('post_id').eq('user_id', me).order('created_at', ascending: false).limit(60);
        final ids = saves.map((r) => r['post_id'].toString()).toList();
        if (ids.isEmpty) return <FeedPost>[];
        final rows = await _db
            .from('posts')
            .select(_postSelect)
            .inFilter('id', ids);
        final byId = {for (final r in rows) r['id'].toString(): Map<String, dynamic>.from(r)};
        // Keep the order the user saved them in.
        final ordered = ids.where(byId.containsKey).map((id) => byId[id]!).toList();
        return _hydrate(ordered);
      });

  // ------------------------------------------------------------------
  // Feed
  // ------------------------------------------------------------------

  @override
  Future<List<FeedPost>?> cachedFeed() async {
    final raw = await _cache.read('cache.feed');
    if (raw is! List) return null;
    return raw.map((e) => FeedPost.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Users I blocked, and users who blocked me. Their posts are hidden from the feed.
  Future<Set<String>> _hiddenAuthors() async {
    final me = _me;
    final rows = await _db.from('blocked_users').select('blocker, blocked').or('blocker.eq.$me,blocked.eq.$me');
    final out = <String>{};
    for (final r in rows) {
      final a = r['blocker'].toString();
      final b = r['blocked'].toString();
      out.add(a == me ? b : a);
    }
    return out;
  }

  /// One page of the feed, newest first. Only the first page is cached for offline use.
  @override
  Future<List<FeedPost>> fetchFeedPage({DateTime? before, int limit = 10}) => _guard(() async {
        var query = _db.from('posts').select(_postSelect);
        if (before != null) {
          query = query.lt('created_at', before.toUtc().toIso8601String());
        }
        final rows = await query.order('created_at', ascending: false).limit(limit);
        final hidden = await _hiddenAuthors();
        final posts = rows
            .map((e) => Map<String, dynamic>.from(e))
            .where((p) => !hidden.contains(p['author_id'].toString()))
            .toList();
        final list = await _hydrate(posts);
        if (before == null) {
          await _cache.write('cache.feed', list.map((p) => p.toMap()).toList());
        }
        return list;
      });

  @override
  Future<List<FeedPost>> fetchFeed() => fetchFeedPage(limit: 10);

  /// Turns raw post rows into FeedPost objects with author, counts, and my like/save/follow state.
  Future<List<FeedPost>> _hydrate(List<Map<String, dynamic>> posts) async {
    if (posts.isEmpty) return <FeedPost>[];
    final me = _me;

    final postIds = posts.map((p) => p['id'].toString()).toList();
    final authorIds = posts.map((p) => p['author_id'].toString()).toSet().toList();

    final profiles = await _profilesFor(authorIds);
    final counts = await _countsOrEmpty(postIds);
    final likeRows = await _db.from('post_likes').select('post_id').eq('user_id', me).inFilter('post_id', postIds);
    final saveRows = await _db.from('post_saves').select('post_id').eq('user_id', me).inFilter('post_id', postIds);
    final followRows = await _db.from('follows').select('followee').eq('follower', me);

    final liked = {for (final r in likeRows) r['post_id'].toString()};
    final saved = {for (final r in saveRows) r['post_id'].toString()};
    final following = {for (final r in followRows) r['followee'].toString()};

    return posts.map((p) {
      final pid = p['id'].toString();
      final aid = p['author_id'].toString();
      final profile = profiles[aid] ?? <String, dynamic>{};

      String? mediaUrl;
      String? mediaType;
      String? thumbUrl;
      final mediaList = (p['post_media'] as List?)
              ?.map((m) => Map<String, dynamic>.from(m as Map))
              .toList() ??
          <Map<String, dynamic>>[];
      mediaList.sort((a, b) => ((a['position'] as num?) ?? 0).compareTo((b['position'] as num?) ?? 0));
      if (mediaList.isNotEmpty) {
        final m = mediaList.first;
        mediaType = m['kind']?.toString();
        if (m['storage_path'] != null) mediaUrl = _publicMediaUrl(m['storage_path'].toString());
        if (m['thumb_path'] != null) thumbUrl = _publicMediaUrl(m['thumb_path'].toString());
      }

      final media = mediaList.map<Map<String, dynamic>>((m) {
        final path = m['storage_path']?.toString();
        final thumb = m['thumb_path']?.toString();
        return {
          'type': m['kind']?.toString() ?? 'image',
          'url': path != null ? _publicMediaUrl(path) : null,
          'thumbUrl': thumb != null ? _publicMediaUrl(thumb) : null,
          'width': (m['width'] as num?)?.toInt() ?? 0,
          'height': (m['height'] as num?)?.toInt() ?? 0,
        };
      }).where((m) => m['url'] != null).toList();

      return FeedPost(
        id: pid,
        authorId: aid,
        user: (profile['username'] ?? 'user').toString(),
        displayName: (profile['display_name'] ?? '').toString(),
        avatarUrl: profile['avatar_url']?.toString(),
        caption: (p['text'] ?? '').toString(),
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        thumbUrl: thumbUrl,
        views: (p['views'] as num?)?.toInt() ?? 0,
        ageMinutes: _ageMinutes(p['created_at']),
        likes: counts[pid]?['likes'] ?? (p['likes'] as num?)?.toInt() ?? 0,
        comments: counts[pid]?['comments'] ?? 0,
        shares: counts[pid]?['shares'] ?? 0,
        liked: liked.contains(pid),
        isSaved: saved.contains(pid),
        isFollowing: following.contains(aid),
        createdAt: DateTime.tryParse((p['created_at'] ?? '').toString()),
        media: media,
      );
    }).toList();
  }

  @override
  Future<LikeResult> setLike(String postId, bool liked) => _guard(() async {
        final me = _me;
        final existing = await _db.from('post_likes').select('post_id').eq('post_id', postId).eq('user_id', me);
        if (liked && existing.isEmpty) {
          await _db.from('post_likes').insert({'post_id': postId, 'user_id': me});
        } else if (!liked && existing.isNotEmpty) {
          await _db.from('post_likes').delete().eq('post_id', postId).eq('user_id', me);
        }
        final post = await _db.from('posts').select('likes').eq('id', postId).single();
        return LikeResult(liked: liked, count: (post['likes'] as num?)?.toInt() ?? 0);
      });

  @override
  Future<bool> setSave(String postId, bool saved) => _guard(() async {
        final me = _me;
        final existing = await _db.from('post_saves').select('post_id').eq('post_id', postId).eq('user_id', me);
        if (saved && existing.isEmpty) {
          await _db.from('post_saves').insert({'post_id': postId, 'user_id': me});
        } else if (!saved && existing.isNotEmpty) {
          await _db.from('post_saves').delete().eq('post_id', postId).eq('user_id', me);
        }
        return saved;
      });

  @override
  Future<bool> setFollow(String authorId, bool following) => _guard(() async {
        final me = _me;
        if (authorId == me) throw const DataException("You can't follow yourself.");
        final existing = await _db.from('follows').select('followee').eq('follower', me).eq('followee', authorId);
        if (following && existing.isEmpty) {
          await _db.from('follows').insert({'follower': me, 'followee': authorId});
        } else if (!following && existing.isNotEmpty) {
          await _db.from('follows').delete().eq('follower', me).eq('followee', authorId);
        }
        return following;
      });

  // ------------------------------------------------------------------
  // Comments
  // ------------------------------------------------------------------

  /// Saved comments, plus comments sent while offline that are still waiting in the outbox,
  /// so they stay visible when the sheet is closed and opened again.
  @override
  Future<List<CommentModel>?> cachedComments(String postId) async {
    final raw = await _cache.read('cache.comments.$postId');
    final flat = raw is List
        ? raw.map((e) => CommentModel.fromFlat(Map<String, dynamic>.from(e as Map))).toList()
        : <CommentModel>[];

    final outbox = await _cache.read('outbox');
    if (outbox is List) {
      final me = _db.auth.currentUser?.id ?? '';
      final prof = await cachedMyProfile();
      for (final e in outbox) {
        if (e is! Map || e['kind'] != 'comment') continue;
        final args = Map<String, dynamic>.from(e['args'] as Map);
        if (args['postId']?.toString() != postId) continue;
        final tempId = args['tempId']?.toString();
        if (tempId == null || flat.any((c) => c.id == tempId)) continue;
        final avatar = prof?['avatar_url']?.toString();
        flat.add(CommentModel(
          id: tempId,
          parentId: args['parentId']?.toString(),
          authorId: me,
          user: (prof?['username'] ?? 'You').toString(),
          avatarUrl: (avatar != null && avatar.isNotEmpty) ? avatar : null,
          text: (args['text'] ?? '').toString(),
          time: 'now',
        ));
      }
    }
    if (raw is! List && flat.isEmpty) return null;
    return buildCommentTree(flat);
  }

  @override
  Future<List<CommentModel>> fetchComments(String postId) => _guard(() async {
        final me = _me;
        final rows = await _db
            .from('comments')
            .select('id, post_id, parent_id, author_id, text, created_at')
            .eq('post_id', postId)
            .order('created_at', ascending: true);
        final list = rows.map((e) => Map<String, dynamic>.from(e)).toList();

        final ids = list.map((r) => r['id'].toString()).toList();
        final authorIds = list.map((r) => r['author_id'].toString()).toSet().toList();
        final profiles = await _profilesFor(authorIds);

        final likeRows = ids.isEmpty
            ? <Map<String, dynamic>>[]
            : await _db.from('comment_likes').select('comment_id, user_id').inFilter('comment_id', ids);
        final counts = <String, int>{};
        final mine = <String>{};
        for (final r in likeRows) {
          final cid = r['comment_id'].toString();
          counts[cid] = (counts[cid] ?? 0) + 1;
          if (r['user_id'].toString() == me) mine.add(cid);
        }

        final flat = list.map((r) {
          final id = r['id'].toString();
          final aid = r['author_id'].toString();
          final age = _ageMinutes(r['created_at']);
          return CommentModel(
            id: id,
            parentId: r['parent_id']?.toString(),
            authorId: aid,
            user: (profiles[aid]?['username'] ?? 'user').toString(),
            avatarUrl: profiles[aid]?['avatar_url']?.toString(),
            text: (r['text'] ?? '').toString(),
            time: formatAge(age),
            ageMinutes: age,
            likes: counts[id] ?? 0,
            liked: mine.contains(id),
          );
        }).toList();

        await _cache.write('cache.comments.$postId', flat.map((c) => c.toFlat()).toList());
        return buildCommentTree(flat);
      });

  @override
  Future<CommentModel> addComment(String postId, String text, {String? parentId, String? tempId}) => _guard(() async {
        final me = _me;
        final resolvedParent = await _resolveId(parentId);
        final row = await _db
            .from('comments')
            .insert({'post_id': postId, 'author_id': me, 'text': text, 'parent_id': resolvedParent})
            .select()
            .single();
        final serverId = row['id'].toString();
        if (tempId != null) {
          final map = Map<String, dynamic>.from((await _cache.read('cache.tmpids') as Map?) ?? {});
          map[tempId] = serverId;
          await _cache.write('cache.tmpids', map);
        }
        final profile = await _profilesFor([me]);
        return CommentModel(
          id: serverId,
          parentId: resolvedParent,
          authorId: me,
          user: (profile[me]?['username'] ?? kCurrentUser).toString(),
          avatarUrl: profile[me]?['avatar_url']?.toString(),
          text: text,
          time: 'now',
        );
      });

  /// A reply made to a comment that was still waiting for the server: use its server id once it has one.
  Future<String?> _resolveId(String? id) async {
    if (id == null || !id.startsWith('tmp')) return id;
    final map = (await _cache.read('cache.tmpids') as Map?) ?? {};
    final real = map[id]?.toString();
    if (real == null) throw const DataException('Waiting for the comment above to send.', retryable: true);
    return real;
  }

  @override
  Future<LikeResult> setCommentLike(String commentId, bool liked) => _guard(() async {
        final me = _me;
        final existing = await _db.from('comment_likes').select('comment_id').eq('comment_id', commentId).eq('user_id', me);
        if (liked && existing.isEmpty) {
          await _db.from('comment_likes').insert({'comment_id': commentId, 'user_id': me});
        } else if (!liked && existing.isNotEmpty) {
          await _db.from('comment_likes').delete().eq('comment_id', commentId).eq('user_id', me);
        }
        final all = await _db.from('comment_likes').select('comment_id').eq('comment_id', commentId);
        return LikeResult(liked: liked, count: all.length);
      });

  @override
  Future<List<StoryViewerModel>> fetchStoryViewers(String storyId) => _guard(() async {
        // 1. Get everyone who viewed the story
        final views = await _db
            .from('story_views')
            .select('viewer_id, created_at')
            .eq('story_id', storyId)
            .order('created_at', ascending: false);
        
        if (views.isEmpty) return [];

        final viewerIds = views.map((v) => v['viewer_id'].toString()).toList();

        // 2. Get their reactions
        final reactions = await _db
            .from('story_reactions')
            .select('user_id, emoji')
            .eq('story_id', storyId)
            .inFilter('user_id', viewerIds);
        
        final reactionMap = <String, String>{};
        for (final r in reactions) {
          reactionMap[r['user_id'].toString()] = r['emoji'].toString();
        }

        // 3. Get their profiles
        final profiles = await _db
            .from('profiles')
            .select('id, username, avatar_url')
            .inFilter('id', viewerIds);
        
        final profileMap = {for (final p in profiles) p['id'].toString(): Map<String, dynamic>.from(p)};

        // 4. Combine and use C++ score for sorting
        final list = views.map((v) {
          final id = v['viewer_id'].toString();
          final prof = profileMap[id] ?? <String, dynamic>{};
          return StoryViewerModel(
            userId: id,
            username: (prof['username'] ?? 'user').toString(),
            avatarUrl: prof['avatar_url']?.toString(),
            reaction: reactionMap[id],
          );
        }).toList();

        return list;
      });

  // ------------------------------------------------------------------
  // User Profiles
  // ------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>> fetchUserProfile(String userId) => _guard(() async {
        final me = _me;
        
        // 1. Get profile data
        final row = await _db
            .from('profiles')
            .select('id, username, display_name, avatar_url, followers_count, following_count, bio')
            .eq('id', userId)
            .maybeSingle();
        
        if (row == null) throw const DataException('User not found');
        
        // 2. Get post count
        final postCount = (await _db.from('posts').select('id').eq('author_id', userId)).length;
        
        // 3. Check relationships
        final iFollow = await _db.from('follows').select('followee').eq('follower', me).eq('followee', userId);
        final followsMe = await _db.from('follows').select('follower').eq('followee', me).eq('follower', userId);

        final profile = Map<String, dynamic>.from(row);
        profile['posts_count'] = postCount;
        profile['isFollowing'] = iFollow.isNotEmpty;
        profile['followsMe'] = followsMe.isNotEmpty;
        
        return profile;
      });

  @override
  Future<List<FeedPost>> fetchUserPosts(String userId) => _guard(() async {
        final rows = await _db
            .from('posts')
            .select(_postSelect)
            .eq('author_id', userId)
            .order('created_at', ascending: false)
            .limit(60);
        final list = await _hydrate(rows.map((e) => Map<String, dynamic>.from(e)).toList());
        // Use C++ core to rank them
        list.sort((a, b) => b.score.compareTo(a.score));
        return list;
      });

  // ------------------------------------------------------------------
  // Notifications
  // ------------------------------------------------------------------

  @override
  Future<void> deleteAllNotifications() => _guard(() async {
        final me = _me;
        await _db.from('notifications').delete().eq('user_id', me);
        // Row-level security silently skips rows it refuses, so confirm the table is empty for this user.
        final left = await _db.from('notifications').select('id').eq('user_id', me).limit(1);
        if (left.isNotEmpty) {
          throw const DataException("Couldn't delete every notification. Try again.", retryable: true);
        }
      });

  /// The username without any leading @, so "@kurt" and "kurt" match the same profile.
  String _cleanHandle(Object? raw) => (raw ?? '').toString().trim().replaceFirst(RegExp(r'^@+'), '');

  @override
  Future<List<NotificationModel>> fetchNotifications() => _guard(() async {
        final me = _me;
        final rows = await _db
            .from('notifications')
            .select('id, type, actor_handle, actor_name, avatar_url, post_id, comment_id, created_at')
            .eq('user_id', me)
            .order('created_at', ascending: false)
            .limit(100);
        final list = rows.map((e) => Map<String, dynamic>.from(e)).toList();
        if (list.isEmpty) return <NotificationModel>[];

        // Following, unfollowing and following again makes a new row each time. Show each person once
        // per follow kind, with the newest first. Likes and comments stay as they are.
        final seen = <String>{};
        final unique = <Map<String, dynamic>>[];
        for (final r in list) {
          final type = r['type'].toString();
          final handle = _cleanHandle(r['actor_handle']).toLowerCase();
          // A follow, unfollow or re-follow adds a row each time: show one per person.
          // Other kinds show once per person, per kind, per post or comment.
          final key = type.toLowerCase().contains('follow')
              ? 'follow|$handle'
              : '$type|$handle|${r['post_id'] ?? ''}|${r['comment_id'] ?? ''}';
          if (seen.add(key)) unique.add(r);
        }

        final handles = unique.map((r) => _cleanHandle(r['actor_handle'])).where((h) => h.isNotEmpty).toSet().toList();
        final profiles = handles.isEmpty
            ? <Map<String, dynamic>>[]
            : (await _db.from('profiles').select('id, username, avatar_url').inFilter('username', handles))
                .map((p) => Map<String, dynamic>.from(p))
                .toList();
        final profileMap = {for (final p in profiles) p['username'].toString().toLowerCase(): p};

        final followRows = await _db.from('follows').select('followee').eq('follower', me);
        final following = {for (final r in followRows) r['followee'].toString()};

        return unique.map((r) {
          final handle = _cleanHandle(r['actor_handle']);
          final prof = profileMap[handle.toLowerCase()] ?? <String, dynamic>{};
          final actorId = (prof['id'] ?? '').toString();
          final profAvatar = prof['avatar_url']?.toString();
          final rowAvatar = r['avatar_url']?.toString();
          final avatar = (profAvatar != null && profAvatar.isNotEmpty)
              ? profAvatar
              : ((rowAvatar != null && rowAvatar.isNotEmpty) ? rowAvatar : null);
          return NotificationModel(
            id: r['id'].toString(),
            type: r['type'].toString(),
            actorId: actorId,
            actorUsername: handle,
            actorAvatarUrl: avatar,
            timeAgo: formatAge(_ageMinutes(r['created_at'])),
            isFollowing: following.contains(actorId),
          );
        }).toList();
      });

  @override
  Future<void> blockUser(String userId) => _guard(() async {
        await _db.rpc('block_user', params: {'p_target': userId});
      });

  @override
  Future<void> restrictUser(String userId) => _guard(() async {
        final me = _me;
        await _db.from('restricted_users').insert({'restrictor': me, 'restricted': userId});
      });

  // ------------------------------------------------------------------
  // Outbox
  // ------------------------------------------------------------------

  @override
  Future<dynamic> run(OutboxOp op) {
    final a = op.args;
    switch (op.kind) {
      case 'like':
        return setLike(a['postId'] as String, a['liked'] as bool);
      case 'save':
        return setSave(a['postId'] as String, a['saved'] as bool);
      case 'follow':
        return setFollow(a['authorId'] as String, a['following'] as bool);
      case 'comment':
        return addComment(
          a['postId'] as String,
          a['text'] as String,
          parentId: a['parentId'] as String?,
          tempId: a['tempId'] as String?,
        );
      case 'commentLike':
        return setCommentLike(a['commentId'] as String, a['liked'] as bool);
    }
    throw DataException('Unknown action: ${op.kind}');
  }

  // ------------------------------------------------------------------
  // Create post: original file plus a small thumbnail, so feeds show instantly
  // ------------------------------------------------------------------


  String _mime(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Future<FeedPost?> fetchPostPreview(String postId) => _guard(() async {
        final rows = await _db.from('posts').select(_postSelect).eq('id', postId).limit(1);
        if (rows.isEmpty) return null;
        final list = await _hydrate(rows.map((e) => Map<String, dynamic>.from(e)).toList());
        return list.isEmpty ? null : list.first;
      });

  /// The file's extension if we can store it, otherwise [fallback].
  String _extOf(String path, String fallback) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return fallback;
    final ext = path.substring(dot + 1).toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'mp4', 'm4v', 'mov', 'webm'};
    return allowed.contains(ext) ? ext : fallback;
  }

  @override
  Future<void> createPost(String caption, List<Map<String, dynamic>> media) => _guard(() async {
        final me = _me;
        if (media.isEmpty) throw const DataException('Add at least one photo or video.');
        if (media.length > kMaxPostMedia) {
          throw DataException('You can add up to $kMaxPostMedia photos or videos per post.');
        }
        final postId = const Uuid().v4();
        final uploaded = <String>[];

        try {
          // Files go up at the same time. The post and its media rows are written last, so an empty
          // post never shows in the feed while files are still uploading.
          final rows = await Future.wait([
            for (int i = 0; i < media.length; i++) _uploadMedia(me, postId, i, media[i], uploaded),
          ]);
          await _db.from('posts').insert({
            'id': postId,
            'author_id': me,
            'text': caption,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
          await _db.from('post_media').insert(rows);
        } catch (_) {
          // Remove the files of a post that did not save.
          if (uploaded.isNotEmpty) {
            try {
              await _db.storage.from('post-media').remove(uploaded);
            } catch (_) {}
          }
          rethrow;
        }
      });

  /// Uploads one photo or video and its thumbnail. Returns the post_media row.
  Future<Map<String, dynamic>> _uploadMedia(
    String me,
    String postId,
    int i,
    Map<String, dynamic> item,
    List<String> uploaded,
  ) async {
    final bucket = _db.storage.from('post-media');
    final path = item['path'] as String;
    final isVideo = (item['type'] as String) == 'video';
    final file = File(path);
    final ext = _extOf(path, isVideo ? 'mp4' : 'jpg');
    final storagePath = '$me/$postId/$i.$ext';

    await bucket.upload(storagePath, file, fileOptions: FileOptions(contentType: _mime(ext), upsert: true));
    uploaded.add(storagePath);

    // Real size from the picker. Used for the feed card's aspect ratio.
    var width = (item['width'] as num?)?.toInt() ?? 0;
    var height = (item['height'] as num?)?.toInt() ?? 0;
    Uint8List? thumbBytes;
    try {
      if (isVideo) {
        thumbBytes = await VideoThumbnail.thumbnailData(
          video: path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 480,
          quality: 75,
        );
      } else {
        // Decode, rotate and resize on a background isolate (see image_prep.dart).
        final prep = await prepareImage(path);
        if (width <= 0 || height <= 0) {
          width = prep.width;
          height = prep.height;
        }
        thumbBytes = prep.thumbJpeg;
      }
    } catch (_) {
      // A thumbnail that cannot be made must not stop the post. The feed shows a poster instead.
      thumbBytes = null;
    }

    String? thumbPath;
    if (thumbBytes != null) {
      final thumbName = '$me/$postId/$i-thumb.jpg';
      try {
        await bucket.uploadBinary(
          thumbName,
          thumbBytes,
          fileOptions: FileOptions(contentType: 'image/jpeg', upsert: true),
        );
        uploaded.add(thumbName);
        thumbPath = thumbName;
      } catch (_) {
        thumbPath = null;
      }
    }

    return {
      'post_id': postId,
      'position': i,
      'kind': isVideo ? 'video' : 'image',
      'storage_path': storagePath,
      'thumb_path': thumbPath,
      'width': width,
      'height': height,
    };
  }
}
