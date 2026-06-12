import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glossy_card.dart';
import '../../../core/widgets/photo_attach.dart';
import '../providers/community_providers.dart';
import 'member_avatar.dart';

/// Compact feed timestamps: now, 12m, 4h, 3d, then the date.
String _timeAgo(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return DateFormat('MMM d').format(t);
}

/// The wall: a composer on top, then every post newest-first in one glossy
/// sheet with gold hairline rules between — the X layout in house colors.
class PostFeed extends ConsumerWidget {
  const PostFeed({super.key, required this.profilesById});

  /// public_profiles rows keyed by user id, for author names and faces.
  final Map<String, Map<String, dynamic>> profilesById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(communityPostsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Composer(profilesById: profilesById),
        const SizedBox(height: 16),
        posts.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => const GlossyCard(
            child: Text(
              'Could not load the wall.',
              style: TextStyle(color: KColors.negative, fontSize: 13),
            ),
          ),
          data: (data) {
            final topLevel =
                data.where((p) => p['parent_post_id'] == null).toList();
            // data is newest-first, so inserting each reply at the front
            // leaves every thread reading oldest-first.
            final replies = <String, List<Map<String, dynamic>>>{};
            for (final p in data) {
              final parent = p['parent_post_id'] as String?;
              if (parent != null) (replies[parent] ??= []).insert(0, p);
            }
            if (topLevel.isEmpty) {
              return const GlossyCard(
                child: Text(
                  'Quiet so far. Say something.',
                  style: TextStyle(
                    fontSize: 13,
                    color: KColors.memberTextSecondary,
                  ),
                ),
              );
            }
            return GlossyCard(
              padding: EdgeInsets.zero,
              hoverLift: false,
              child: Column(
                children: [
                  for (var i = 0; i < topLevel.length; i++) ...[
                    if (i > 0)
                      Container(
                        height: 1,
                        decoration:
                            const BoxDecoration(gradient: KGold.hairline),
                      ),
                    _PostTile(
                      post: topLevel[i],
                      replies: replies[topLevel[i]['id']] ?? const [],
                      profilesById: profilesById,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer({required this.profilesById});

  final Map<String, Map<String, dynamic>> profilesById;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _body = TextEditingController();
  final _photo = PhotoAttachController();
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    _photo.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _body.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      final imageUrl = _photo.hasPhoto ? await _photo.upload() : null;
      await supabase.from('community_posts').insert({
        'user_id': supabase.auth.currentUser!.id,
        'body': text,
        'image_url': ?imageUrl,
      });
      _body.clear();
      _photo.clear();
      ref.invalidate(communityPostsProvider);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post failed. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.profilesById[supabase.auth.currentUser?.id];
    return GlossyCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      hoverLift: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemberAvatar(
            url: me?['avatar_url'] as String?,
            fallbackInitial: memberInitial(me),
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _body,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 280,
                  style: const TextStyle(fontSize: 14, height: 1.45),
                  decoration: const InputDecoration(
                    hintText: 'Post to the room.',
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    PhotoAttachField(controller: _photo),
                    const Spacer(),
                    FilledButton(
                      style: glossyPrimaryButton().copyWith(
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                        ),
                      ),
                      onPressed: _busy ? null : _post,
                      child: _busy
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Post',
                              style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One post in the X layout: face left; name, handle and time on one line;
/// body; then the quiet action row. Replies render inside the parent along
/// a thin gold thread line.
class _PostTile extends ConsumerStatefulWidget {
  const _PostTile({
    required this.post,
    required this.replies,
    required this.profilesById,
    this.isReply = false,
  });

  final Map<String, dynamic> post;
  final List<Map<String, dynamic>> replies;
  final Map<String, Map<String, dynamic>> profilesById;
  final bool isReply;

  @override
  ConsumerState<_PostTile> createState() => _PostTileState();
}

class _PostTileState extends ConsumerState<_PostTile> {
  final _reply = TextEditingController();
  bool _replyOpen = false;
  bool _busy = false;
  bool _likeBusy = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleLike(bool liked) async {
    if (_likeBusy) return;
    _likeBusy = true;
    final myId = supabase.auth.currentUser!.id;
    try {
      if (liked) {
        await supabase
            .from('post_likes')
            .delete()
            .eq('post_id', widget.post['id'])
            .eq('user_id', myId);
      } else {
        await supabase.from('post_likes').insert({
          'post_id': widget.post['id'],
          'user_id': myId,
        });
      }
      ref.invalidate(communityPostsProvider);
    } on Exception {
      if (mounted) _snack('That did not go through. Try again.');
    } finally {
      _likeBusy = false;
    }
  }

  Future<void> _sendReply() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await supabase.from('community_posts').insert({
        'user_id': supabase.auth.currentUser!.id,
        'parent_post_id': widget.post['id'],
        'body': text,
      });
      _reply.clear();
      setState(() => _replyOpen = false);
      ref.invalidate(communityPostsProvider);
    } on Exception {
      if (mounted) _snack('Reply failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    try {
      await supabase
          .from('community_posts')
          .delete()
          .eq('id', widget.post['id']);
      ref.invalidate(communityPostsProvider);
    } on Exception {
      if (mounted) _snack('Delete failed. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final author = widget.profilesById[p['user_id']];
    final username = author?['username'] as String? ?? 'member';
    final display = memberDisplayName(author);
    final myId = supabase.auth.currentUser?.id;
    final mine = p['user_id'] == myId;
    final likes = (p['post_likes'] as List?) ?? const [];
    final liked = likes.any((l) => l['user_id'] == myId);
    final created =
        DateTime.tryParse(p['created_at'] as String? ?? '')?.toLocal();

    return Padding(
      padding: widget.isReply
          ? const EdgeInsets.fromLTRB(14, 12, 0, 0)
          : const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemberAvatar(
            url: author?['avatar_url'] as String?,
            fallbackInitial: memberInitial(author),
            size: widget.isReply ? 30 : 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        display,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '@$username · ${_timeAgo(created)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: KColors.memberTextSecondary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (mine)
                      PopupMenuButton<String>(
                        onSelected: (_) => _delete(),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(fontSize: 13)),
                          ),
                        ],
                        padding: EdgeInsets.zero,
                        child: const Icon(
                          Icons.more_horiz,
                          size: 16,
                          color: KColors.memberTextSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  p['body'] as String? ?? '',
                  style: const TextStyle(fontSize: 14, height: 1.45),
                ),
                if ((p['image_url'] as String?)?.isNotEmpty == true)
                  AttachedPhoto(url: p['image_url'] as String),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (!widget.isReply)
                      _PostAction(
                        icon: Icons.chat_bubble_outline,
                        count: widget.replies.length,
                        active: _replyOpen,
                        onTap: () =>
                            setState(() => _replyOpen = !_replyOpen),
                      ),
                    if (!widget.isReply) const SizedBox(width: 28),
                    _PostAction(
                      icon: liked ? Icons.favorite : Icons.favorite_border,
                      count: likes.length,
                      active: liked,
                      onTap: () => _toggleLike(liked),
                    ),
                  ],
                ),
                if (widget.replies.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Color(0x33C9A84C)),
                      ),
                    ),
                    child: Column(
                      children: [
                        for (final r in widget.replies)
                          _PostTile(
                            post: r,
                            replies: const [],
                            profilesById: widget.profilesById,
                            isReply: true,
                          ),
                      ],
                    ),
                  ),
                if (_replyOpen)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _reply,
                            maxLength: 280,
                            minLines: 1,
                            maxLines: 4,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Reply to $display',
                              counterText: '',
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              border: const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Color(0x33C9A84C)),
                              ),
                              enabledBorder: const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Color(0x33C9A84C)),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Color(0x8CC9A84C)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _busy ? null : _sendReply,
                          child: const Text('Reply',
                              style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon-plus-count in the action row; gold when the action is live.
class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.count,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color =
        active ? KColors.memberAccent : KColors.memberTextSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text('$count', style: KFonts.data(size: 11.5, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}
