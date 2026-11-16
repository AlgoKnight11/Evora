import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/evora_colors.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../services/location_service.dart';
import '../../auth/services/auth_service.dart';
import '../models/civic_book_model.dart';
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
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(civicBookProvider.notifier).loadComments(widget.postId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final authed = await AuthGuard.requireLogin(
      context,
      ref,
      actionDescription: 'Sign in to post comments on CivicBook observations.',
    );
    if (!authed) return;

    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (!mounted) return;
    setState(() => _isSending = true);
    final ok = await ref.read(civicBookProvider.notifier).addComment(widget.postId, text);
    if (!mounted) return;
    setState(() => _isSending = false);

    if (ok) {
      _commentController.clear();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(civicBookProvider);
    final notifier = ref.read(civicBookProvider.notifier);
    final isAuthenticated = ref.watch(authProvider.select((s) => s.isAuthenticated));
    final postIndex = state.allPosts.indexWhere((p) => p.id == widget.postId);

    if (postIndex == -1) {
      if (state.isLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('Observation')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Observation')),
        body: const Center(child: Text('Post not found or has been removed.')),
      );
    }

    final post = state.allPosts[postIndex];
    final realComments = state.commentsByPost[widget.postId] ?? [];
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
              child: RefreshIndicator(
                onRefresh: () => notifier.loadComments(widget.postId),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                                  '${post.locality} • ${_formatTimestamp(post.createdAt)}',
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
                      const SizedBox(height: 16),

                      // Interactive Voting Kinetic Pill
                      Row(
                        children: [
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
                                    post.currentUserVote == 1
                                        ? Icons.arrow_upward
                                        : Icons.arrow_upward_outlined,
                                    size: 18,
                                    color: post.currentUserVote == 1
                                        ? EvoraColors.primary
                                        : EvoraColors.onSurfaceVariant,
                                  ),
                                  onPressed: () async {
                                    final ok = await AuthGuard.requireLogin(
                                      context,
                                      ref,
                                      actionDescription:
                                          'Sign in to upvote community observations.',
                                    );
                                    if (ok) {
                                      await notifier.toggleVote(post.id, 1);
                                    }
                                  },
                                  visualDensity: VisualDensity.compact,
                                ),
                                Text(
                                  '${post.score}',
                                  style: TextStyle(
                                    fontSize: 13,
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
                                    post.currentUserVote == -1
                                        ? Icons.arrow_downward
                                        : Icons.arrow_downward_outlined,
                                    size: 18,
                                    color: post.currentUserVote == -1
                                        ? EvoraColors.error
                                        : EvoraColors.onSurfaceVariant,
                                  ),
                                  onPressed: () async {
                                    final ok = await AuthGuard.requireLogin(
                                      context,
                                      ref,
                                      actionDescription:
                                          'Sign in to vote on community observations.',
                                    );
                                    if (ok) {
                                      await notifier.toggleVote(post.id, -1);
                                    }
                                  },
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),
                        ],
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
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Needs Municipal Attention?',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  Text(
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
                              onPressed: () async {
                                final ok = await AuthGuard.requireLogin(
                                  context,
                                  ref,
                                  actionDescription:
                                      'Sign in to escalate this observation into a formal CivicFlow grievance.',
                                );
                                if (ok && context.mounted) {
                                  context.push(
                                    '/civic-flow/wizard?sourcePostId=${post.id}&category=${Uri.encodeComponent(post.category)}&title=${Uri.encodeComponent(post.title)}&locality=${Uri.encodeComponent(post.locality)}',
                                  );
                                }
                              },
                              child: const Text('Escalate', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Real Comments Section Header
                      Row(
                        children: [
                          const Icon(Icons.forum_outlined, size: 18, color: EvoraColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Community Comments (${state.isLoadingComments && realComments.isEmpty ? post.commentsCount : realComments.length})',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (state.isLoadingComments && realComments.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (realComments.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: EvoraColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.chat_bubble_outline, color: EvoraColors.outline, size: 28),
                              SizedBox(height: 8),
                              Text(
                                'No comments yet',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Be the first resident to share a real update on this observation.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: realComments.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final comment = realComments[index];
                            return _buildCommentItem(comment);
                          },
                        ),
                    ],
                  ),
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
                      readOnly: !isAuthenticated,
                      onTap: !isAuthenticated
                          ? () => AuthGuard.requireLogin(
                                context,
                                ref,
                                actionDescription:
                                    'Sign in to post comments on CivicBook observations.',
                              )
                          : null,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(),
                      decoration: InputDecoration(
                        hintText: isAuthenticated
                            ? 'Add a real comment to the discussion...'
                            : 'Sign in to add a comment...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildCommentItem(CivicComment comment) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EvoraColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: EvoraColors.primary.withValues(alpha: 0.15),
                child: Text(
                  comment.authorName.isNotEmpty ? comment.authorName[0].toUpperCase() : 'R',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: EvoraColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  comment.authorName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              Text(
                _formatTimestamp(comment.createdAt),
                style: const TextStyle(fontSize: 11, color: EvoraColors.outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comment.text,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }
}
