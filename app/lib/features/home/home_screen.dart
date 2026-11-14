import 'package:flutter/material.dart';

const Color kPrimary = Color(0xFFFF6B35);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  final List<Map<String, dynamic>> _posts = [
    {'user': 'alex', 'likes': 124, 'caption': 'Chasing sunsets 🌅 #swifs', 'time': '2h', 'liked': false},
    {'user': 'mia', 'likes': 89, 'caption': 'Coffee & code ☕️💻', 'time': '5h', 'liked': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            _storiesRow(),
            Expanded(child: _feed()),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: kPrimary), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Create'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Swifs', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kPrimary)),
            Row(children: [
              IconButton(icon: const Icon(Icons.search), onPressed: () {}),
              IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
            ]),
          ],
        ),
      );

  Widget _storiesRow() {
    final stories = ['Your Story', 'alex', 'mia', 'leo', 'zara'];
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 12),
        itemCount: stories.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(children: [
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: i == 0 ? Colors.grey.shade300 : kPrimary, width: 2.5),
              ),
              child: const CircleAvatar(backgroundColor: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(stories[i], style: const TextStyle(fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  Widget _feed() => ListView.builder(
        itemCount: _posts.length,
        itemBuilder: (_, i) {
          final p = _posts[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  const CircleAvatar(radius: 18, backgroundColor: Colors.grey),
                  const SizedBox(width: 8),
                  Text(p['user'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(p['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
              Container(
                height: 350, color: Colors.grey.shade200,
                child: const Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
              ),
              Row(children: [
                IconButton(
                  icon: Icon(p['liked'] ? Icons.favorite : Icons.favorite_border,
                      color: p['liked'] ? kPrimary : null),
                  onPressed: () => setState(() => p['liked'] = !p['liked']),
                ),
                IconButton(icon: const Icon(Icons.chat_bubble_outline), onPressed: () {}),
                IconButton(icon: const Icon(Icons.send_outlined), onPressed: () {}),
                const Spacer(),
                IconButton(icon: const Icon(Icons.bookmark_border), onPressed: () {}),
              ]),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['likes'] + (p['liked'] ? 1 : 0)} likes', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${p['user']} ', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: p['caption']),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      );
}
