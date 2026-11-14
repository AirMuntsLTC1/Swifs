import 'package:flutter/material.dart';

const Color kPrimary = Color(0xFFFF6B35);

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _items = [
    {'icon': Icons.favorite, 'color': kPrimary, 'text': 'alex liked your post', 'time': '10m'},
    {'icon': Icons.chat_bubble, 'color': Colors.blue, 'text': 'mia commented: "love this!"', 'time': '1h'},
    {'icon': Icons.person_add, 'color': Colors.green, 'text': 'leo started following you', 'time': '2h'},
    {'icon': Icons.favorite, 'color': kPrimary, 'text': 'zara liked your post', 'time': '5h'},
  ];

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
