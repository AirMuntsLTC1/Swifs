import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/data/unread_counts.dart';
import '../../core/notifications/realtime_notification_service.dart';
import '../profile/user_profile_screen.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/data/models.dart';
import '../../core/data/social.dart';
import '../../core/theme/swifs_icon.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/swifs_skeleton.dart';
import '../messages/thread_screen.dart';

const Color kPrimary = Color(0xFFFF6B35);
const Color kInk = Color(0xFF111111);
const Color kMuted = Color(0xFF8E8E93);
const Color kLine = Color(0xFFEFEFEF);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _items = [];
  bool _loading = true;
  StreamSubscription<String>? _hubSub;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _hubSub = RealtimeHub.instance.changes.listen((t) {
      if (t == 'notifications' || t == 'resume') _scheduleLoad();
    });
    UnreadCounts.instance.markAllNotificationsRead();
  }

  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _hubSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await social.fetchNotifications();
      if (mounted) setState(() { _items = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow(NotificationModel item) async {
    final was = item.isFollowing;
    setState(() => item.isFollowing = !was);
    try {
      await social.setFollow(item.actorId, !was);
    } catch (_) {
      if (mounted) setState(() => item.isFollowing = was);
    }
  }

  void _openThread(NotificationModel item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThreadScreen(
          otherId: item.actorId,
          label: item.actorUsername,
          username: item.actorUsername,
          avatarUrl: item.actorAvatarUrl,
        ),
      ),
    );
  }

  /// The sentence after the name, by notification type.
  String _actionText(NotificationModel item) {
    switch (item.type) {
      case 'follow':
        return ' started following you. ';
      case 'follow_request':
        return ' wants to follow you. ';
      case 'follow_accept':
        return ' accepted your follow request. ';
      case 'like':
        return ' liked your post. ';
      case 'comment':
        return ' commented on your post. ';
      case 'comment_like':
        return ' liked your comment. ';
      case 'save':
        return ' saved your post. ';
      case 'message':
        return ' sent you a message. ';
      case 'storyReact':
        return ' reacted to your story. ';
      case 'storyReply':
        return ' replied to your story. ';
      default:
        return ' sent you a notification. ';
    }
  }

  /// The button on the right. Messages get Message. Follow rows keep Message or Follow back.
  /// Other activity (likes, comments) has no button.
  Widget? _trailing(NotificationModel item) {
    if (item.type == 'message') return _messageButton(item);
    if (!item.type.startsWith('follow')) return null;
    return item.isFollowing
                          ? GestureDetector(
                              onTap: () => _openThread(item),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F2F5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Message', style: TextStyle(color: kInk, fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            )
                          : GestureDetector(
                              onTap: () => _toggleFollow(item),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: kPrimary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Follow back', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            );
  }

  Widget _messageButton(NotificationModel item) => GestureDetector(
        onTap: () => _openThread(item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('Message', style: TextStyle(color: kInk, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );

  Future<void> _confirmDeleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete all notifications?'),
        content: const Text("This removes every notification from your account. It can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final previous = _items;
    setState(() => _items = []);
    try {
      await social.deleteAllNotifications();
      UnreadCounts.instance.notifications.value = 0;
    } catch (e) {
      if (mounted) {
        setState(() => _items = previous);
        final text = e is DataException ? e.message : "Couldn't delete notifications.";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      }
    }
  }

  void _showSafetyNotice(NotificationModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SafetyNoticeSheet(
        item: item,
        onBlocked: () {
          setState(() => _items.remove(item));
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const SwifsIcon(LucideIcons.arrowLeft, color: kInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications', style: TextStyle(color: kInk, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          if (!_loading && _items.isNotEmpty)
            TextButton(
              onPressed: _confirmDeleteAll,
              child: const Text('Delete all', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _loading
          ? const ListRowsSkeleton()
          : _items.isEmpty
              ? const Center(child: Text('No notifications yet', style: TextStyle(color: kMuted)))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: kLine, indent: 76),
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: GestureDetector(
                        onTap: () => _showSafetyNotice(item),
                        child: GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: item.actorId))),
                          child: UserAvatar(url: item.actorAvatarUrl, name: item.actorUsername, radius: 26),
                        ),
                      ),
                      title: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: kInk, fontSize: 14),
                          children: [
                            TextSpan(text: item.actorUsername, style: const TextStyle(fontWeight: FontWeight.w600)),
                            TextSpan(text: _actionText(item)),
                            TextSpan(text: item.timeAgo, style: const TextStyle(color: kMuted)),
                          ],
                        ),
                      ),
                      trailing: _trailing(item),
                    );
                  },
                ),
    );
  }
}

class _SafetyNoticeSheet extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback onBlocked;

  const _SafetyNoticeSheet({required this.item, required this.onBlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 24),
          Center(child: UserAvatar(url: item.actorAvatarUrl, name: item.actorUsername, radius: 40)),
          const SizedBox(height: 12),
          Center(child: Text('@${item.actorUsername}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kInk))),
          const SizedBox(height: 24),
          const Text('Review account info carefully', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kInk)),
          const SizedBox(height: 8),
          const Text('We provide account info to help you decide who to interact with.', style: TextStyle(color: kMuted, fontSize: 14)),
          const SizedBox(height: 24),
          const Text('Recent updates', style: TextStyle(fontWeight: FontWeight.w600, color: kInk)),
          const SizedBox(height: 12),
          _infoRow(LucideIcons.calendar, 'Joined Swifs recently'),
          _infoRow(LucideIcons.user, 'Username updated recently'),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                builder: (ctx) => _ActionSheet(item: item, onBlocked: onBlocked),
              );
            },
            child: const Text('Take action'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SwifsIcon(icon, size: 20, color: kInk),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: kInk, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ActionSheet extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback onBlocked;

  const _ActionSheet({required this.item, required this.onBlocked});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Actions you can take', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kInk)),
            const SizedBox(height: 8),
            ListTile(
              leading: const SwifsIcon(LucideIcons.userX, color: kInk),
              title: const Text('Restrict', style: TextStyle(color: kInk)),
              onTap: () async {
                await social.restrictUser(item.actorId);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const SwifsIcon(LucideIcons.ban, color: Colors.red),
              title: const Text('Block', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await social.blockUser(item.actorId);
                if (context.mounted) Navigator.pop(context);
                onBlocked();
              },
            ),
          ],
        ),
      ),
    );
  }
}
