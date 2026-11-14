import 'package:flutter/material.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import '../../core/theme/swifs_refresh.dart';
import '../../core/theme/swifs_icon.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import 'settings_screen.dart';

const Color kPrimary = Color(0xFFFF6B35);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);

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
            child: buildSwifsRefreshIcon(LucideIcons.user),
          ),
        ),
        controller: _refreshController,
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          _refreshController.refreshCompleted();
        },
        child: DefaultTabController(
          length: 3,
          child: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverToBoxAdapter(
                child: Padding(
                  // Added top padding to respect status bar
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 42,
                            backgroundColor: Color(0xFFE4E6EB),
                            child: SwifsIcon(LucideIcons.user, size: 42, color: Colors.grey),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: const [
                                _Stat('0', 'Posts'),
                                _Stat('0', 'Followers'),
                                _Stat('0', 'Following'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            SizedBox(height: 4),
                            Text('Building Swifs 🚀', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    const begin = Offset(1.0, 0.0); // Slide from right
                                    const end = Offset.zero;
                                    const curve = Curves.easeOutCubic;
                                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                    return SlideTransition(position: animation.drive(tween), child: child);
                                  },
                                ),
                              );
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF0F2F5),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SwifsIcon(LucideIcons.settings, size: 20, color: Colors.black),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: TabBar(
                  indicatorColor: kPrimary,
                  labelColor: kPrimary,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(icon: SwifsIcon(LucideIcons.grid3x3)),
                    Tab(icon: SwifsIcon(LucideIcons.play)),
                    Tab(icon: SwifsIcon(LucideIcons.bookmark)),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              children: List.generate(3, (idx) {
                return GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: 12,
                  itemBuilder: (_, i) => Container(
                    color: const Color(0xFFF0F2F5),
                    child: const Center(child: SwifsIcon(LucideIcons.image, color: Colors.grey)),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}