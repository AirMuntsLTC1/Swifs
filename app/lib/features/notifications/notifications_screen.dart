import 'package:flutter/material.dart';
import '../../core/mocks/mock_notifications.dart';

const Color kPrimary = Color(0xFFFF6B35);

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _items = mockNotifications;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) {
                final it = _items[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (it['color'] as Color).withOpacity(0.15),
                    child: Icon(it['icon'] as IconData, color: it['color'] as Color),
                  ),
                  title: Text(it['text'] as String),
                  subtitle: Text(it['time'] as String, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
