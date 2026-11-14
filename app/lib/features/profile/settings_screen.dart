import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/theme/swifs_icon.dart';

const Color kPrimary = Color(0xFFFF6B35);
const Color kInk = Color(0xFF111111);
const Color kMuted = Color(0xFF8E8E93);
const Color kLine = Color(0xFFEFEFEF);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Who can see your content
  String _accountPrivacy = 'Public';
  final int _closeFriends = 0;
  bool _friendsFeedActivity = true;

  // How others can interact with you
  String _messages = 'Everyone';
  String _tags = 'Everyone';
  String _comments = 'Everyone';
  bool _sharingReuse = true;
  String _limitInteractions = 'Off';
  bool _hiddenWords = true;

  // What you see / notifications
  bool _pushNotifications = true;
  bool _likeNotifications = true;
  bool _commentNotifications = true;
  bool _followNotifications = true;

  static const _audience = ['Everyone', 'Followers', 'Off'];

  Future<void> _pick({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onPick,
  }) async {
    final choice = await showModalBottomSheet<String>(
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
    if (choice != null && mounted) {
      setState(() => onPick(choice));
    }
  }

  void _openPage(String title, String emptyText, IconData icon) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EmptyPage(title: title, text: emptyText, icon: icon),
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out')),
      );
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
            _row(
              icon: LucideIcons.lock,
              label: 'Account privacy',
              value: _accountPrivacy,
              onTap: () => _pick(
                title: 'Account privacy',
                options: const ['Public', 'Private'],
                current: _accountPrivacy,
                onPick: (v) => _accountPrivacy = v,
              ),
            ),
            _row(
              icon: LucideIcons.star,
              label: 'Close Friends',
              value: '$_closeFriends',
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
              value: '0',
              onTap: () => _openPage(
                'Blocked',
                'Accounts you block will show up here.',
                LucideIcons.ban,
              ),
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
              value: _friendsFeedActivity,
              onChanged: (v) => setState(() => _friendsFeedActivity = v),
            ),
          ]),
          _section('How others can interact with you', [
            _row(
              icon: LucideIcons.send,
              label: 'Messages and story replies',
              value: _messages,
              onTap: () => _pick(
                title: 'Messages and story replies',
                options: _audience,
                current: _messages,
                onPick: (v) => _messages = v,
              ),
            ),
            _row(
              icon: LucideIcons.atSign,
              label: 'Tags and mentions',
              value: _tags,
              onTap: () => _pick(
                title: 'Tags and mentions',
                options: _audience,
                current: _tags,
                onPick: (v) => _tags = v,
              ),
            ),
            _row(
              icon: LucideIcons.messageCircle,
              label: 'Comments',
              value: _comments,
              onTap: () => _pick(
                title: 'Comments',
                options: _audience,
                current: _comments,
                onPick: (v) => _comments = v,
              ),
            ),
            _switchRow(
              icon: LucideIcons.share2,
              label: 'Sharing and reuse',
              subtitle: 'Allow others to share your posts',
              value: _sharingReuse,
              onChanged: (v) => setState(() => _sharingReuse = v),
            ),
            _row(
              icon: LucideIcons.eyeOff,
              label: 'Restricted',
              value: '0',
              onTap: () => _openPage(
                'Restricted',
                'Restricted accounts can see your posts but cannot message you.',
                LucideIcons.eyeOff,
              ),
            ),
            _row(
              icon: LucideIcons.shield,
              label: 'Limit interactions',
              value: _limitInteractions,
              onTap: () => _pick(
                title: 'Limit interactions',
                options: const ['Off', 'On'],
                current: _limitInteractions,
                onPick: (v) => _limitInteractions = v,
              ),
            ),
            _switchRow(
              icon: LucideIcons.type,
              label: 'Hidden Words',
              subtitle: 'Hide comments and messages with words you choose',
              value: _hiddenWords,
              onChanged: (v) => setState(() => _hiddenWords = v),
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
              value: _pushNotifications,
              onChanged: (v) => setState(() => _pushNotifications = v),
            ),
            _switchRow(
              icon: LucideIcons.heart,
              label: 'Likes',
              value: _likeNotifications,
              onChanged: (v) => setState(() => _likeNotifications = v),
            ),
            _switchRow(
              icon: LucideIcons.messageCircle,
              label: 'Comments',
              value: _commentNotifications,
              onChanged: (v) => setState(() => _commentNotifications = v),
            ),
            _switchRow(
              icon: LucideIcons.userPlus,
              label: 'New followers',
              value: _followNotifications,
              onChanged: (v) => setState(() => _followNotifications = v),
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
      body: Center(
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
      ),
    );
  }
}
