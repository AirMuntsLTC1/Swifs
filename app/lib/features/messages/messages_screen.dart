import 'package:flutter/material.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import '../../core/theme/swifs_refresh.dart';
import '../../core/theme/swifs_icon.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';

const Color kPrimary = Color(0xFFFF6B35);

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);

  static const _chats = [
    {'user': 'alex', 'message': 'Hey, loved your last post!', 'time': '2m'},
    {'user': 'mia', 'message': 'Are we still on for coffee?', 'time': '1h'},
    {'user': 'leo', 'message': 'Sent you a photo', 'time': '3h'},
    {'user': 'zara', 'message': 'Haha that is so true', 'time': '1d'},
  ];

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SmartRefresher(
        enablePullDown: true,
        header: CustomHeader(
          height: 60.0,
          builder: (context, mode) => Center(
            child: buildSwifsRefreshIcon(LucideIcons.messageSquare),
          ),
        ),
        controller: _refreshController,
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          _refreshController.refreshCompleted();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Messages', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _chats.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (_, i) {
                  final chat = _chats[i];
                  return ListTile(
                    leading: const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFFE4E6EB),
                      child: SwifsIcon(LucideIcons.user, color: Colors.grey),
                    ),
                    title: Text('@${chat['user']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(chat['message'] as String, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    trailing: Text(chat['time'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}