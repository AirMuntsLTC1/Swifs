import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show NoSplash;
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
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
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
  late PageController _pageController;

  final List<Widget> _screens = const [
    HomeScreen(),
    ExploreScreen(),
    MessagesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_index == index) return;
    
    setState(() {
      _index = index;
    });

    // This creates the Slide Left/Right animation
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0, // Only allow closing the app if on Home tab
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // If user presses back on another tab, smoothly slide back to Home (Index 0)
        if (_index != 0) {
          _onTabTapped(0);
        }
      },
      child: Scaffold(
      // PageView allows sliding left and right between screens
      body: SafeArea(
        top: false,
        bottom: false,
        child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Prevents swiping with fingers, forces tab taps
        onPageChanged: (index) => setState(() => _index = index),
        children: _screens,
      ),
      ),
      
      // Custom Navigation Bar
      bottomNavigationBar: Container(
        height: 56 + MediaQuery.of(context).padding.bottom,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F2F5), width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, LucideIcons.house, 'Home'),
            _buildNavItem(1, LucideIcons.search, 'Find'),
            _buildNavItem(2, LucideIcons.messageSquare, 'Messages'),
            _buildNavItem(3, LucideIcons.user, 'Profile'),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _index == index;
    final color = isSelected ? kPrimary : Colors.black;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SwifsIcon(
              icon,
              size: 24,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
