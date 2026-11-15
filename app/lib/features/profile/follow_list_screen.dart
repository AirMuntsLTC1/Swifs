import 'package:flutter/material.dart';

import '../../core/data/social.dart';
import '../../core/widgets/user_avatar.dart';
import 'user_profile_screen.dart';

const Color _kInk = Color(0xFF111111);
const Color _kMuted = Color(0xFF8E8E93);

/// Who follows a person, or who they follow. Tap a row to open that profile.
class FollowListScreen extends StatefulWidget {
  final String userId;
  final bool followers;

  const FollowListScreen({super.key, required this.userId, required this.followers});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<Map<String, dynamic>>? _users;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await social.fetchFollowList(widget.userId, followers: widget.followers);
      if (mounted) setState(() {
        _users = list;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.followers ? 'Followers' : 'Following';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: _kInk, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: _kInk,
        elevation: 0,
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    final users = _users;
    if (users == null) {
      if (_failed) return _message("Couldn't load. Pull down to try again.");
      return const Center(child: CircularProgressIndicator());
    }
    if (users.isEmpty) {
      return _message(widget.followers ? 'No followers yet' : 'Not following anyone yet');
    }
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, i) {
        final u = users[i];
        final display = (u['display_name'] ?? '').toString().trim();
        final username = (u['username'] ?? '').toString();
        return ListTile(
          leading: UserAvatar(
            url: u['avatar_url']?.toString(),
            name: display.isNotEmpty ? display : username,
            radius: 22,
          ),
          title: Text(display.isNotEmpty ? display : username),
          subtitle: Text('@$username', style: const TextStyle(color: _kMuted)),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserProfileScreen(userId: u['id'].toString())),
          ),
        );
      },
    );
  }

  Widget _message(String text) => ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(text, style: const TextStyle(color: _kMuted))),
        ],
      );
}
