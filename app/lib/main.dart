import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show NoSplash;
import 'core/theme/swifs_icon.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import 'features/home/home_screen.dart';
import 'features/explore/explore_screen.dart';
import 'features/messages/messages_screen.dart';
import 'features/profile/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/auth/auth_gate.dart';
import 'core/network/interaction_queue.dart';
import 'core/notifications/realtime_notification_service.dart';
import 'core/notifications/realtime_lifecycle.dart';
import 'core/data/unread_counts.dart';
import 'core/widgets/count_badge.dart';

const Color kPrimary = Color(0xFFFF6B35);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);

  // Realtime and the outbox run only for a signed-in user. Starting them before login
  // (the old way) meant they never ran after a login made during the session.
  void syncSession(Session? session) {
    if (session != null) {
      RealtimeHub.instance.start();
      UnreadCounts.instance.start();
      InteractionQueue.instance.restore();
    } else {
      RealtimeHub.instance.stop();
      UnreadCounts.instance.stop();
    }
  }

  syncSession(Supabase.instance.client.auth.currentSession);
  RealtimeLifecycle.instance.attach();
  Supabase.instance.client.auth.onAuthStateChange.listen((state) => syncSession(state.session));

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
      home: const AuthGate(child: MainShell()),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Any screen can ask the main shell to slide to a tab (0 Home, 1 Find, 2 Messages, 3 Profile).
  /// Set it to the tab index; the shell moves there and clears it.
  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

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
    MainShell.requestedTab.addListener(_onRequestedTab);
  }

  @override
  void dispose() {
    MainShell.requestedTab.removeListener(_onRequestedTab);
    _pageController.dispose();
    super.dispose();
  }

  void _onRequestedTab() {
    final tab = MainShell.requestedTab.value;
    if (tab == null) return;
    MainShell.requestedTab.value = null;
    _onTabTapped(tab);
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
            ValueListenableBuilder<int>(
              valueListenable: UnreadCounts.instance.messages,
              builder: (context, count, _) => CountBadge(
                count: index == 2 ? count : 0,
                child: SwifsIcon(icon, size: 24, color: color),
              ),
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
