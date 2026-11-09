import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/evora_colors.dart';
import '../../../services/location_service.dart';
import '../services/civic_book_service.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    final ok = await ref.read(civicBookProvider.notifier).addComment(widget.postId, text);
    setState(() => _isSending = false);

    if (ok) {
      _commentController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(civicBookProvider);
    final postIndex = state.allPosts.indexWhere((p) => p.id == widget.postId);

    if (postIndex == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Observation')),
        body: const Center(child: Text('Post not found or has been removed.')),
      );
    }

    final post = state.allPosts[postIndex];
    final distanceText = post.distanceKm != null
        ? LocationService.formatDistance(post.distanceKm!)
        : 'Nearby';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Observation'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author & Distance Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: EvoraColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'R',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: EvoraColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.authorName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              Text(
                                post.locality,
                                style: const TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: EvoraColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            distanceText,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF006948),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Photo if available
                    if (post.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          post.imageUrl!,
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Description Body
                    Text(
                      post.description,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: EvoraColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Escalation Banner to Municipal Grievance
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            EvoraColors.tertiaryContainer.withValues(alpha: 0.2),
                            EvoraColors.surfaceContainerLowest,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: EvoraColors.tertiary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, color: EvoraColors.tertiary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Needs Municipal Attention?',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                const Text(
                                  'Escalate this directly into an official CivicFlow grievance case.',
                                  style: TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EvoraColors.tertiary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () {
                              context.push(
                                '/civic-flow/wizard?sourcePostId=${post.id}&category=${Uri.encodeComponent(post.category)}&title=${Uri.encodeComponent(post.title)}&locality=${Uri.encodeComponent(post.locality)}',
                              );
                            },
                            child: const Text('Escalate', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Comments Section Header
                    Row(
                      children: [
                        const Icon(Icons.forum_outlined, size: 18, color: EvoraColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Community Comments (${post.commentsCount})',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sample community comments
                    _buildCommentItem('Neha Pant', '2h ago', 'I pass through this intersection every day. It has gotten much worse today!'),
                    const SizedBox(height: 12),
                    _buildCommentItem('Aditya Joshi', '45m ago', 'Upvoted! Municipal truck should prioritize this immediately.'),
                  ],
                ),
              ),
            ),

            // Comment Composer Input Field
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.paddingOf(context).bottom),
              decoration: BoxDecoration(
                color: EvoraColors.surfaceContainerLowest,
                border: Border(
                  top: BorderSide(color: EvoraColors.outlineVariant.withValues(alpha: 0.3)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add to the discussion...',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: EvoraColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 18),
                    onPressed: _isSending ? null : _submitComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(String author, String time, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EvoraColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                author,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Text(
                time,
                style: const TextStyle(fontSize: 11, color: EvoraColors.outline),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }
}
