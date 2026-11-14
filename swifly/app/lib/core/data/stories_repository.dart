import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// One sticker, text, or location tag placed on a story.
/// x and y are 0..1 across the story canvas, so every phone draws it in the same place.
class StoryLayer {
  String kind; // text | sticker | location
  String value;
  int color;
  double x;
  double y;
  double scale;
  double rotation; // radians

  StoryLayer({
    required this.kind,
    required this.value,
    this.color = 0xFFFFFFFF,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 1,
    this.rotation = 0,
  });

  StoryLayer copy() => StoryLayer(
        kind: kind,
        value: value,
        color: color,
        x: x,
        y: y,
        scale: scale,
        rotation: rotation,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'value': value,
        'color': color,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
      };

  factory StoryLayer.fromJson(Map<String, dynamic> m) => StoryLayer(
        kind: (m['kind'] ?? 'text').toString(),
        value: (m['value'] ?? '').toString(),
        color: (m['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
        x: (m['x'] as num?)?.toDouble() ?? 0.5,
        y: (m['y'] as num?)?.toDouble() ?? 0.5,
        scale: (m['scale'] as num?)?.toDouble() ?? 1,
        rotation: (m['rotation'] as num?)?.toDouble() ?? 0,
      );
}

class StoryItem {
  final String id;
  final String authorId;
  final String photoUrl;
  final List<StoryLayer> layers;
  final DateTime createdAt;

  const StoryItem({
    required this.id,
    required this.authorId,
    required this.photoUrl,
    required this.layers,
    required this.createdAt,
  });
}

/// All active stories from one person, in order.
class StoryGroup {
  final String authorId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isMine;
  final List<StoryItem> stories = [];
  final Set<String> viewedIds = {};

  StoryGroup({
    required this.authorId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.isMine,
  });

  bool get allSeen => stories.isNotEmpty && stories.every((s) => viewedIds.contains(s.id));

  String get label => displayName.trim().isNotEmpty ? displayName.trim() : username;
}

/// Loads, sends, and uploads stories. Uploads run in the background; the home ring shows their progress.
class StoriesRepository {
  StoriesRepository._();
  static final StoriesRepository instance = StoriesRepository._();

  /// null when idle, otherwise 0..1 while sharing. Home draws this as the blue ring fill.
  static final ValueNotifier<double?> uploadProgress = ValueNotifier<double?>(null);

  /// Set when a share fails. Home shows it once and clears it.
  static final ValueNotifier<String?> uploadError = ValueNotifier<String?>(null);

  static const _bucket = 'stories';

  SupabaseClient get _db => Supabase.instance.client;

  String? get _meOrNull => _db.auth.currentUser?.id;

  String _publicUrl(String path) {
    final base = _db.rest.url.replaceAll('/rest/v1', '');
    return '$base/storage/v1/object/public/$_bucket/$path';
  }

  /// Active stories (last 24 hours) from people you follow and from you.
  /// Order: yours first, then people with new stories, then people you have fully watched.
  Future<List<StoryGroup>> fetchRail() async {
    final me = _meOrNull;
    if (me == null) return [];

    final rows = await _db
        .from('stories')
        .select('id, author_id, photo_path, layers, created_at, expires_at')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: true);
    final list = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    if (list.isEmpty) return [];

    final authorIds = list.map((r) => r['author_id'].toString()).toSet().toList();
    final profileRows = await _db
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .inFilter('id', authorIds);
    final profiles = {for (final p in profileRows) p['id'].toString(): Map<String, dynamic>.from(p)};

    final viewRows = await _db.from('story_views').select('story_id').eq('viewer_id', me);
    final viewed = {for (final v in viewRows) v['story_id'].toString()};

    final groups = <String, StoryGroup>{};
    for (final r in list) {
      final aid = r['author_id'].toString();
      final prof = profiles[aid] ?? <String, dynamic>{};
      final group = groups.putIfAbsent(
        aid,
        () => StoryGroup(
          authorId: aid,
          username: (prof['username'] ?? 'user').toString(),
          displayName: (prof['display_name'] ?? '').toString(),
          avatarUrl: prof['avatar_url']?.toString(),
          isMine: aid == me,
        ),
      );
      final raw = r['layers'];
      final layers = raw is List
          ? raw.map((e) => StoryLayer.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : <StoryLayer>[];
      final id = r['id'].toString();
      final photo = r['photo_path']?.toString() ?? '';
      group.stories.add(StoryItem(
        id: id,
        authorId: aid,
        photoUrl: photo.isEmpty ? '' : _publicUrl(photo),
        layers: layers,
        createdAt: DateTime.tryParse(r['created_at'].toString()) ?? DateTime.now(),
      ));
      if (viewed.contains(id)) group.viewedIds.add(id);
    }

    final out = groups.values.toList();
    out.sort((a, b) {
      if (a.isMine != b.isMine) return a.isMine ? -1 : 1;
      if (a.allSeen != b.allSeen) return a.allSeen ? 1 : -1;
      return 0;
    });
    return out;
  }

  Future<void> markViewed(String storyId) async {
    final me = _meOrNull;
    if (me == null) return;
    await _db.from('story_views').upsert(
      {'story_id': storyId, 'viewer_id': me},
      onConflict: 'story_id,viewer_id',
      ignoreDuplicates: true,
    );
  }

  Future<int> viewerCount(String storyId) async {
    final rows = await _db.from('story_views').select('viewer_id').eq('story_id', storyId);
    return rows.length;
  }

  Future<void> react(String storyId, String emoji) async {
    final me = _meOrNull;
    if (me == null) throw StateError('Please sign in.');
    await _db.from('story_reactions').insert({'story_id': storyId, 'user_id': me, 'emoji': emoji});
  }

  /// Saves the reply on the story, and sends it to the owner's Messages with the story attached.
  Future<void> reply(String storyId, String ownerId, String text) async {
    final me = _meOrNull;
    if (me == null) throw StateError('Please sign in.');
    await _db.from('story_replies').insert({'story_id': storyId, 'user_id': me, 'text': text});
    if (ownerId != me) {
      await _db.from('messages').insert({
        'sender': me,
        'recipient': ownerId,
        'text': text,
        'story_id': storyId,
      });
    }
  }

  /// Starts sharing in the background. Returns at once so the screen can close and the ring can fill.
  void startUpload({required File photo, required List<StoryLayer> layers}) {
    if (uploadProgress.value != null) {
      uploadError.value = 'Still sharing your last story. Try again in a moment.';
      return;
    }
    unawaited(_upload(photo, layers.map((l) => l.copy()).toList()));
  }

  Future<void> _upload(File photo, List<StoryLayer> layers) async {
    final me = _meOrNull;
    if (me == null) {
      uploadError.value = 'Please sign in to share a story.';
      return;
    }

    final id = const Uuid().v4();
    final ext = photo.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final path = '$me/$id.$ext';

    uploadError.value = null;
    uploadProgress.value = 0.02;

    // The upload client does not report bytes sent, so the ring moves steadily toward 85%
    // while the file uploads, then jumps to full when the story row is saved.
    final crawl = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final p = uploadProgress.value;
      if (p == null) return;
      if (p < 0.85) uploadProgress.value = p + (0.85 - p) * 0.08;
    });

    try {
      final bytes = await photo.readAsBytes();
      uploadProgress.value = 0.1;

      await _db.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
              upsert: true,
            ),
          );

      final now = DateTime.now().toUtc();
      await _db.from('stories').insert({
        'id': id,
        'author_id': me,
        'bg_color': 0,
        'photo_path': path,
        'photo_scale': 1.0,
        'photo_dx': 0.0,
        'photo_dy': 0.0,
        'photo_rotation': 0.0,
        'layers': layers.map((l) => l.toJson()).toList(),
        'place': null,
        'created_at': now.toIso8601String(),
        'expires_at': now.add(const Duration(hours: 24)).toIso8601String(),
      });

      crawl.cancel();
      uploadProgress.value = 1.0;
      await Future<void>.delayed(const Duration(milliseconds: 450));
      uploadProgress.value = null;
    } catch (_) {
      crawl.cancel();
      uploadProgress.value = null;
      uploadError.value = "Couldn't share your story. Check your connection and try again.";
    }
  }
}
