import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/swifs_icon.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import 'features/home/home_screen.dart';
import 'features/explore/explore_screen.dart';
import 'features/messages/messages_screen.dart';
import 'features/profile/profile_screen.dart';

const Color kPrimary = Color(0xFFFF6B35);

void main() {
  runApp(const ProviderScope(child: SwifsApp()));
}

class SwifsApp extends StatelessWidget {
  const SwifsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swifs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: kPrimary,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        colorSchemeSeed: kPrimary,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    ExploreScreen(),
    MessagesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: SwifsIcon(LucideIcons.house),
            selectedIcon: SwifsIcon(LucideIcons.house, color: kPrimary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: SwifsIcon(LucideIcons.search),
            selectedIcon: SwifsIcon(LucideIcons.search, color: kPrimary),
            label: 'Find',
          ),
          NavigationDestination(
            icon: SwifsIcon(LucideIcons.messageSquare),
            selectedIcon: SwifsIcon(LucideIcons.messageSquare, color: kPrimary),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFFBDBDBD),
              child: SwifsIcon(LucideIcons.user, size: 14, color: Colors.white),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
