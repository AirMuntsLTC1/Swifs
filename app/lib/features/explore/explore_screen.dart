import 'package:flutter/material.dart';
import '../../core/mocks/mock_explore.dart';

const Color kPrimary = Color(0xFFFF6B35);

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  static const _tags = mockTags;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search Swifs',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
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
                children: _tags
                    .map((t) => Chip(
                          label: Text(t),
                          backgroundColor: Colors.grey.shade100,
                          side: BorderSide.none,
                          labelStyle: const TextStyle(color: kPrimary, fontWeight: FontWeight.w600),
                        ))
                    .toList(),
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
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                ),
                childCount: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
