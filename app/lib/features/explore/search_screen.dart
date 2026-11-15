import 'dart:async';
import 'package:flutter/material.dart';
import '../profile/user_profile_screen.dart';
import '../../core/theme/swifs_icon.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/data/social.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/swifs_skeleton.dart';
import '../../core/auth/current_user.dart';

const Color kPrimary = Color(0xFFFF6B35);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _fetch('');
  }

  /// Waits a moment after typing, then asks the server. Old answers that arrive late are ignored.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _fetch(value));
  }

  Future<void> _fetch(String query) async {
    final id = ++_requestId;
    if (mounted) setState(() => _loading = true);
    try {
      final users = query.trim().isEmpty
          ? await social.suggestedUsers()
          : await social.searchUsers(query);
      if (!mounted || id != _requestId) return;
      setState(() {
        _users = users.where((u) => !isMyAccount(u['id'])).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleFollow(int index) async {
    final user = _users[index];
    final id = user['id'].toString();
    final was = user['isFollowing'] == true;
    setState(() => user['isFollowing'] = !was);
    try {
      final result = await social.setFollow(id, !was);
      if (mounted) setState(() => user['isFollowing'] = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => user['isFollowing'] = was);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const SwifsIcon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onChanged,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
            decoration: InputDecoration(
              hintText: 'Search Swifs...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 10, right: 6),
                child: SwifsIcon(LucideIcons.search, size: 18, color: Colors.grey),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _users.isEmpty) {
      return const LoadingList();
    }
    if (_error != null && _users.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text("Couldn't search right now. Check your connection.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
      ));
    }
    if (_users.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.trim().isEmpty ? 'No suggestions yet' : 'No people found',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
      itemBuilder: (_, i) {
        final user = _users[i];
        final display = (user['display_name'] ?? '').toString().trim();
        final username = (user['username'] ?? '').toString();
        final following = user['isFollowing'] == true;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: user['id'].toString()))),
                child: UserAvatar(
                  url: user['avatar_url']?.toString(),
                  name: display.isNotEmpty ? display : username,
                  radius: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      display.isNotEmpty ? display : username,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text('@$username', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      '${user['followers_count'] ?? 0} followers · ${user['following_count'] ?? 0} following',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!isMyAccount(user['id'])) GestureDetector(
                onTap: () => _toggleFollow(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: following ? const Color(0xFFE4E6EB) : kPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    following ? 'Following' : 'Follow',
                    style: TextStyle(
                      color: following ? Colors.black : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
