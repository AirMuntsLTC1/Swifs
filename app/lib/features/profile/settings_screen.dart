import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/cache/local_cache.dart';
import '../../core/data/settings_repository.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/theme/swifs_icon.dart';
import '../../core/widgets/swifs_skeleton.dart';
import 'package:cached_network_image/cached_network_image.dart';

const Color kPrimary = Color(0xFFFF6B35);
const Color kInk = Color(0xFF111111);
const Color kMuted = Color(0xFF8E8E93);
const Color kLine = Color(0xFFEFEFEF);

const List<String> _audience = ['Everyone', 'Followers', 'Off'];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserSettings _s = UserSettings.defaults();
  int _blocked = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Shows the saved copy from the phone right away, then refreshes from Supabase.
  Future<void> _load() async {
    final cached = await SettingsRepository.instance.cachedSettings();
    if (cached != null && mounted) setState(() => _s = cached);

    final fresh = await SettingsRepository.instance.loadSettings();
    final blocked = await _blockedCountSafe();
    if (!mounted) return;
    setState(() {
      _s = fresh;
      _blocked = blocked;
    });
  }

  Future<int> _blockedCountSafe() async {
    try {
      return await SettingsRepository.instance.blockedCount();
    } catch (_) {
      return 0;
    }
  }

  /// Applies the change on screen immediately, then saves it to Supabase.
  Future<void> _update(UserSettings next) async {
    setState(() => _s = next);
    try {
      await SettingsRepository.instance.saveSettings(next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Saved on this phone, but couldn't reach the server. Try again later."),
        ),
      );
    }
  }

  Future<String?> _pick({
    required String title,
    required List<String> options,
    required String current,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                ),
              ),
            ),
            for (final option in options)
              ListTile(
                title: Text(option, style: const TextStyle(color: kInk)),
                trailing: option == current
                    ? const Icon(Icons.check, color: kPrimary)
                    : null,
                onTap: () => Navigator.pop(ctx, option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openPage(String title, String emptyText, IconData icon) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EmptyPage(title: title, text: emptyText, icon: icon),
      ),
    );
  }

  Future<void> _openBlocked() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _BlockedPage()),
    );
    final count = await _blockedCountSafe();
    if (mounted) setState(() => _blocked = count);
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use Swifs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await AuthService.signOut();
      await LocalCache.instance.clearUserData();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const SwifsIcon(LucideIcons.arrowLeft, color: kInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings and activity',
          style: TextStyle(
            color: kInk,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _section('Who can see your content', [
            _choiceRow(
              icon: LucideIcons.lock,
              label: 'Account privacy',
              value: _s.accountPrivacy,
              title: 'Account privacy',
              options: const ['Public', 'Private'],
              onPicked: (v) => _update(_s.copyWith(accountPrivacy: v)),
            ),
            _row(
              icon: LucideIcons.star,
              label: 'Close Friends',
              onTap: () => _openPage(
                'Close Friends',
                'People you add here can see your close friends stories.',
                LucideIcons.star,
              ),
            ),
            _row(
              icon: LucideIcons.grid3x3,
              label: 'Crossposting',
              onTap: () => _openPage(
                'Crossposting',
                'Connect other apps to share your posts automatically.',
                LucideIcons.grid3x3,
              ),
            ),
            _row(
              icon: LucideIcons.ban,
              label: 'Blocked',
              value: '$_blocked',
              onTap: _openBlocked,
            ),
            _row(
              icon: LucideIcons.clock,
              label: 'Story, live and location',
              onTap: () => _openPage(
                'Story, live and location',
                'Control who can reply to your stories and go live.',
                LucideIcons.clock,
              ),
            ),
            _switchRow(
              icon: LucideIcons.users,
              label: 'Activity in Friends feed',
              subtitle: 'Let friends see what you like and follow',
              value: _s.friendsFeedActivity,
              onChanged: (v) => _update(_s.copyWith(friendsFeedActivity: v)),
            ),
          ]),
          _section('How others can interact with you', [
            _choiceRow(
              icon: LucideIcons.send,
              label: 'Messages and story replies',
              value: _s.messagesAudience,
              title: 'Messages and story replies',
              options: _audience,
              onPicked: (v) => _update(_s.copyWith(messagesAudience: v)),
            ),
            _choiceRow(
              icon: LucideIcons.atSign,
              label: 'Tags and mentions',
              value: _s.tagsAudience,
              title: 'Tags and mentions',
              options: _audience,
              onPicked: (v) => _update(_s.copyWith(tagsAudience: v)),
            ),
            _choiceRow(
              icon: LucideIcons.messageCircle,
              label: 'Comments',
              value: _s.commentsAudience,
              title: 'Comments',
              options: _audience,
              onPicked: (v) => _update(_s.copyWith(commentsAudience: v)),
            ),
            _switchRow(
              icon: LucideIcons.share2,
              label: 'Sharing and reuse',
              subtitle: 'Allow others to share your posts',
              value: _s.sharingReuse,
              onChanged: (v) => _update(_s.copyWith(sharingReuse: v)),
            ),
            _row(
              icon: LucideIcons.eyeOff,
              label: 'Restricted',
              onTap: () => _openPage(
                'Restricted',
                'Restricted accounts can see your posts but cannot message you.',
                LucideIcons.eyeOff,
              ),
            ),
            _choiceRow(
              icon: LucideIcons.shield,
              label: 'Limit interactions',
              value: _s.limitInteractions,
              title: 'Limit interactions',
              options: const ['Off', 'On'],
              onPicked: (v) => _update(_s.copyWith(limitInteractions: v)),
            ),
            _switchRow(
              icon: LucideIcons.type,
              label: 'Hidden Words',
              subtitle: 'Hide comments and messages with words you choose',
              value: _s.hiddenWords,
              onChanged: (v) => _update(_s.copyWith(hiddenWords: v)),
            ),
            _row(
              icon: LucideIcons.userPlus,
              label: 'Follow and invite friends',
              onTap: () => _openPage(
                'Follow and invite friends',
                'Invite friends to Swifs and find people you know.',
                LucideIcons.userPlus,
              ),
            ),
          ]),
          _section('What you see', [
            _switchRow(
              icon: LucideIcons.bell,
              label: 'Push notifications',
              value: _s.pushNotifications,
              onChanged: (v) => _update(_s.copyWith(pushNotifications: v)),
            ),
            _switchRow(
              icon: LucideIcons.heart,
              label: 'Likes',
              value: _s.likeNotifications,
              onChanged: (v) => _update(_s.copyWith(likeNotifications: v)),
            ),
            _switchRow(
              icon: LucideIcons.messageCircle,
              label: 'Comments',
              value: _s.commentNotifications,
              onChanged: (v) => _update(_s.copyWith(commentNotifications: v)),
            ),
            _switchRow(
              icon: LucideIcons.userPlus,
              label: 'New followers',
              value: _s.followNotifications,
              onChanged: (v) => _update(_s.copyWith(followNotifications: v)),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _confirmLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Log out',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            title,
            style: const TextStyle(
              color: kMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...rows,
      ],
    );
  }

  Widget _choiceRow({
    required IconData icon,
    required String label,
    required String value,
    required String title,
    required List<String> options,
    required ValueChanged<String> onPicked,
  }) {
    return _row(
      icon: icon,
      label: label,
      value: value,
      onTap: () async {
        final choice = await _pick(title: title, options: options, current: value);
        if (choice != null && choice != value && mounted) onPicked(choice);
      },
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    String? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SwifsIcon(icon, size: 22, color: kInk),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: kInk,
                ),
              ),
            ),
            if (value != null)
              Text(
                value,
                style: const TextStyle(fontSize: 14, color: kMuted),
              ),
            const SizedBox(width: 6),
            const SwifsIcon(LucideIcons.chevronRight, size: 18, color: kMuted),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            SwifsIcon(icon, size: 22, color: kInk),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: kInk,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: kMuted),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: kPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lists the accounts you blocked, with an Unblock button for each.
class _BlockedPage extends StatefulWidget {
  const _BlockedPage();

  @override
  State<_BlockedPage> createState() => _BlockedPageState();
}

class _BlockedPageState extends State<_BlockedPage> {
  List<Map<String, dynamic>> _people = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final people = await SettingsRepository.instance.loadBlocked();
      if (!mounted) return;
      setState(() {
        _people = people;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load blocked accounts.";
      });
    }
  }

  Future<void> _unblock(String id) async {
    try {
      await SettingsRepository.instance.unblock(id);
      if (!mounted) return;
      setState(() => _people.removeWhere((p) => p['id'].toString() == id));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't unblock. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const LoadingList();
    } else if (_error != null) {
      body = Center(child: Text(_error!, style: const TextStyle(color: kMuted)));
    } else if (_people.isEmpty) {
      body = const _EmptyBody(
        icon: LucideIcons.ban,
        text: 'Accounts you block will show up here.',
      );
    } else {
      body = ListView.builder(
        itemCount: _people.length,
        itemBuilder: (_, i) {
          final p = _people[i];
          final id = p['id'].toString();
          final name = ((p['display_name'] as String?) ?? '').trim();
          final handle = (p['username'] as String?) ?? '';
          final avatar = p['avatar_url'] as String?;
          final label = name.isNotEmpty ? name : handle;
          final initial = label.isEmpty ? '?' : label[0].toUpperCase();
          final hasAvatar = avatar != null && avatar.isNotEmpty;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: kLine,
              backgroundImage: hasAvatar ? CachedNetworkImageProvider(avatar, maxWidth: 200, maxHeight: 200) : null,
              child: hasAvatar
                  ? null
                  : Text(
                      initial,
                      style: const TextStyle(color: kInk, fontWeight: FontWeight.w700),
                    ),
            ),
            title: Text(label, style: const TextStyle(color: kInk)),
            subtitle: handle.isNotEmpty
                ? Text('@$handle', style: const TextStyle(color: kMuted))
                : null,
            trailing: OutlinedButton(
              onPressed: () => _unblock(id),
              child: const Text('Unblock'),
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const SwifsIcon(LucideIcons.arrowLeft, color: kInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Blocked',
          style: TextStyle(color: kInk, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: body,
    );
  }
}

class _EmptyBody extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyBody({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwifsIcon(icon, size: 48, color: kMuted),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: kMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPage extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;

  const _EmptyPage({required this.title, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const SwifsIcon(LucideIcons.arrowLeft, color: kInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: kInk,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _EmptyBody(icon: icon, text: text),
    );
  }
}
