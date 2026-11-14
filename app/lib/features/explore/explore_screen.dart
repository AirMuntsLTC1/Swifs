import 'package:flutter/material.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import '../../core/theme/swifs_refresh.dart';
import '../../core/theme/swifs_icon.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/data/social.dart';
import 'search_screen.dart';

const Color kPrimary = Color(0xFFFF6B35);

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    _fetchTags();
  }

  Future<void> _fetchTags() async {
    try {
      final tags = await social.fetchTrendingTags();
      if (mounted) setState(() => _tags = tags);
    } catch (_) {}
  }

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
            child: buildSwifsRefreshIcon(LucideIcons.search),
          ),
        ),
        controller: _refreshController,
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          _refreshController.refreshCompleted();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const SearchScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          const begin = Offset(0.0, 1.0);
                          const end = Offset.zero;
                          const curve = Curves.easeOutCubic;
                          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                          return SlideTransition(position: animation.drive(tween), child: child);
                        },
                      ),
                    );
                  },
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        const SwifsIcon(LucideIcons.search, size: 18, color: Colors.grey),
                        const SizedBox(width: 10),
                        const Text('Search Swifs', style: TextStyle(color: Colors.grey, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((t) => Chip(
                    label: Text(t),
                    backgroundColor: Colors.grey.shade100,
                    side: BorderSide.none,
                    labelStyle: const TextStyle(color: kPrimary, fontWeight: FontWeight.w500),
                  )).toList(),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(4),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Container(
                    color: const Color(0xFFF0F2F5),
                    child: const Center(child: SwifsIcon(LucideIcons.image, color: Colors.grey)),
                  ),
                  childCount: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}