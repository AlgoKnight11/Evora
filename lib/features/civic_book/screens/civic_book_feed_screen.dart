import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/evora_colors.dart';
import '../../../services/location_service.dart';
import '../models/civic_book_model.dart';
import '../services/civic_book_service.dart';

class CivicBookFeedScreen extends ConsumerWidget {
  const CivicBookFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(civicBookProvider);
    final notifier = ref.read(civicBookProvider.notifier);
    final posts = state.filteredPosts;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.dynamic_feed_outlined, color: EvoraColors.primary, size: 22),
            SizedBox(width: 8),
            Text('CivicBook Feed'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Feed',
            onPressed: () => notifier.refreshPosts(),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // Geofence Radius & Location Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: EvoraColors.surfaceContainerLowest,
                border: Border(
                  bottom: BorderSide(
                    color: EvoraColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: EvoraColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.userLocation.localityName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: EvoraColors.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 3 km / 5 km Geofence Toggle Pill
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: EvoraColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRadiusPill(
                          label: '3 km',
                          isSelected: state.selectedRadiusKm == 3.0,
                          onTap: () => notifier.setRadius(3.0),
                        ),
                        _buildRadiusPill(
                          label: '5 km',
                          isSelected: state.selectedRadiusKm == 5.0,
                          onTap: () => notifier.setRadius(5.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Category Filter Strip
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: [
                  _buildCategoryChip('all', 'All Issues', Icons.all_inclusive, state.selectedCategory, notifier),
                  _buildCategoryChip('waste', 'Waste & Garbage', Icons.delete_outline, state.selectedCategory, notifier),
                  _buildCategoryChip('roads', 'Roads & Potholes', Icons.add_road_outlined, state.selectedCategory, notifier),
                  _buildCategoryChip('water', 'Water Leakage', Icons.water_drop_outlined, state.selectedCategory, notifier),
                  _buildCategoryChip('lights', 'Streetlights', Icons.lightbulb_outline, state.selectedCategory, notifier),
                  _buildCategoryChip('greenery', 'Greenery & Trees', Icons.park_outlined, state.selectedCategory, notifier),
                ],
              ),
            ),

            // Posts Feed List
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : posts.isEmpty
                      ? RefreshIndicator(
                          onRefresh: () => notifier.refreshPosts(),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.nature_people_outlined, size: 64, color: EvoraColors.outline),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No observations within ${state.selectedRadiusKm.toInt()} km',
                                            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Try expanding to 5 km or be the first neighbor to post a community report!',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: EvoraColors.onSurfaceVariant, fontSize: 13),
                                          ),
                                          const SizedBox(height: 20),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.add),
                                            label: const Text('Post First Observation'),
                                            onPressed: () => context.push('/civic-book/create'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => notifier.refreshPosts(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            itemCount: posts.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final post = posts[index];
                              return _buildPostCard(context, post, notifier);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: EvoraColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Post Observation'),
        onPressed: () => context.push('/civic-book/create'),
      ),
    );
  }

  Widget _buildRadiusPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? EvoraColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : EvoraColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    String categoryKey,
    String label,
    IconData icon,
    String selectedCategory,
    CivicBookNotifier notifier,
  ) {
    final isSelected = selectedCategory.toLowerCase() == categoryKey.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : EvoraColors.primary),
        label: Text(label),
        selected: isSelected,
        selectedColor: EvoraColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : EvoraColors.onSurface,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
        backgroundColor: EvoraColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
          side: BorderSide(
            color: isSelected ? EvoraColors.primary : EvoraColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        onSelected: (_) => notifier.setCategory(categoryKey),
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, CivicBookPost post, CivicBookNotifier notifier) {
    final distanceText = post.distanceKm != null
        ? LocationService.formatDistance(post.distanceKm!)
        : 'Nearby';

    return Container(
      decoration: BoxDecoration(
        color: EvoraColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: EvoraColors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/civic-book/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author & Proximity Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: EvoraColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'R',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: EvoraColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          post.locality,
                          style: const TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Distance Pill Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: EvoraColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distanceText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF006948),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),

              // Description
              Text(
                post.description,
                style: TextStyle(
                  fontSize: 13,
                  color: EvoraColors.onSurfaceVariant.withValues(alpha: 0.9),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // Post Photo Preview if attached
              if (post.imageUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    post.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Action Bar: Upvote/Downvote kinetic pill, Comments, & Escalate Shortcut
              Row(
                children: [
                  // Upvote / Downvote Kinetic Bar
                  Container(
                    decoration: BoxDecoration(
                      color: EvoraColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            post.currentUserVote == 1 ? Icons.arrow_upward : Icons.arrow_upward_outlined,
                            size: 18,
                            color: post.currentUserVote == 1 ? EvoraColors.primary : EvoraColors.onSurfaceVariant,
                          ),
                          onPressed: () => notifier.toggleVote(post.id, 1),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          constraints: const BoxConstraints(),
                        ),
                        Text(
                          '${post.score}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: post.score > 0
                                ? EvoraColors.primary
                                : post.score < 0
                                    ? EvoraColors.error
                                    : EvoraColors.onSurfaceVariant,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            post.currentUserVote == -1 ? Icons.arrow_downward : Icons.arrow_downward_outlined,
                            size: 18,
                            color: post.currentUserVote == -1 ? EvoraColors.error : EvoraColors.onSurfaceVariant,
                          ),
                          onPressed: () => notifier.toggleVote(post.id, -1),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Comments Counter
                  TextButton.icon(
                    icon: const Icon(Icons.mode_comment_outlined, size: 16),
                    label: Text('${post.commentsCount}'),
                    style: TextButton.styleFrom(
                      foregroundColor: EvoraColors.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => context.push('/civic-book/${post.id}'),
                  ),

                  const Spacer(),

                  // The Bridge: "Raise Formal Case" Action
                  OutlinedButton.icon(
                    icon: const Icon(Icons.bolt, size: 16, color: EvoraColors.tertiary),
                    label: const Text('Escalate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EvoraColors.tertiary,
                      side: const BorderSide(color: EvoraColors.tertiary, width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    onPressed: () {
                      // Pre-fill CivicFlow wizard with this observation
                      context.push(
                        '/civic-flow/wizard?sourcePostId=${post.id}&category=${Uri.encodeComponent(post.category)}&title=${Uri.encodeComponent(post.title)}&locality=${Uri.encodeComponent(post.locality)}',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
