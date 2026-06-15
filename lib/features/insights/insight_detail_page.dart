import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/glossy_card.dart';
import '../../core/widgets/photo_attach.dart';
import 'providers/insight_providers.dart';

/// Full view of one insight — K's take in full, plus the member discussion
/// thread (questions and comments), the same model trades use.
class InsightDetailPage extends ConsumerWidget {
  const InsightDetailPage({super.key, required this.insightId});

  final String insightId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(insightDetailProvider(insightId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: insight.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const GlossyCard(
              child: Text(
                'Could not load this insight.',
                style: TextStyle(color: KColors.negative, fontSize: 13),
              ),
            ),
            data: (i) {
              if (i == null) {
                return GlossyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This insight is no longer available.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.go('/dashboard'),
                        child: const Text('← Back to dashboard',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }
              return _InsightDetail(insight: i, insightId: insightId);
            },
          ),
        ),
      ),
    );
  }
}

class _InsightDetail extends StatelessWidget {
  const _InsightDetail({required this.insight, required this.insightId});

  final Map<String, dynamic> insight;
  final String insightId;

  @override
  Widget build(BuildContext context) {
    final i = insight;
    final date = DateTime.parse(i['insight_date'] as String);
    final bias = i['market_bias'] as String?;
    final ticker = i['scope'] == 'ticker' ? i['ticker'] as String? : null;
    final tags = (i['macro_tags'] as List?)?.cast<String>() ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back, size: 14),
          label: const Text('Dashboard', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(height: 12),
        GlossyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    DateFormat('MMM d, yyyy').format(date),
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.5,
                      color: KColors.memberTextSecondary,
                    ),
                  ),
                  if (ticker != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      ticker.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: KColors.memberAccent,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (bias != null) _BiasChip(bias: bias),
                ],
              ),
              const SizedBox(height: 12),
              Text(i['title'] as String, style: KFonts.heading(size: 24)),
              const SizedBox(height: 12),
              Text(
                i['body'] as String,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
              if ((i['image_url'] as String?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 14),
                AttachedPhoto(url: i['image_url'] as String, maxHeight: 420),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x14C9A84C),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 11,
                            color: KColors.memberAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DiscussionCard(insightId: insightId),
      ],
    );
  }
}

class _BiasChip extends StatelessWidget {
  const _BiasChip({required this.bias});

  final String bias;

  static const _biasColors = {
    'bullish': KColors.positive,
    'bearish': KColors.negative,
    'neutral': KColors.neutral,
    'cautious': KColors.pending,
  };

  @override
  Widget build(BuildContext context) {
    final color = _biasColors[bias] ?? KColors.neutral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        bias.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: color,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: KColors.memberTextSecondary,
      ),
    );
  }
}

// ---- Discussion ----

class _DiscussionCard extends ConsumerStatefulWidget {
  const _DiscussionCard({required this.insightId});

  final String insightId;

  @override
  ConsumerState<_DiscussionCard> createState() => _DiscussionCardState();
}

class _DiscussionCardState extends ConsumerState<_DiscussionCard> {
  final _body = TextEditingController();
  bool _isQuestion = false;
  bool _busy = false;
  String? _error;

  Future<void> _post() async {
    final body = _body.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.from('insight_comments').insert({
        'insight_id': widget.insightId,
        'user_id': supabase.auth.currentUser!.id,
        'body': body,
        'is_question': _isQuestion,
      });
      _body.clear();
      setState(() => _isQuestion = false);
      ref.invalidate(insightThreadProvider(widget.insightId));
    } on Exception catch (e) {
      setState(() => _error = 'Could not post: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(insightThreadProvider(widget.insightId));
    final tier = ref.watch(memberTierProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final canPost = isAdmin || tier == 'inner_circle';

    return GlossyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          thread.maybeWhen(
            data: (d) {
              if (d.comments.isEmpty) return const _Label('Discussion');
              final q =
                  d.comments.where((c) => c['is_question'] == true).length;
              final c = d.comments.length - q;
              final parts = [
                if (q > 0) '$q question${q == 1 ? '' : 's'}',
                if (c > 0) '$c comment${c == 1 ? '' : 's'}',
              ];
              return _Label('Discussion · ${parts.join(' · ')}');
            },
            orElse: () => const _Label('Discussion'),
          ),
          const SizedBox(height: 8),
          thread.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Text(
              'Could not load the discussion.',
              style: TextStyle(color: KColors.negative, fontSize: 13),
            ),
            data: (d) => d.comments.isEmpty
                ? const Text(
                    'No comments yet.',
                    style: TextStyle(
                      fontSize: 13,
                      color: KColors.memberTextSecondary,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final c in d.comments)
                        _CommentTile(
                          key: ValueKey(c['id']),
                          comment: c,
                          username: d.usernames[c['user_id']] ?? 'member',
                          insightId: widget.insightId,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          if (canPost) ...[
            Container(
              height: 1,
              decoration: const BoxDecoration(gradient: KGold.hairline),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _body,
              maxLines: 4,
              minLines: 1,
              maxLength: 2000,
              style: const TextStyle(fontSize: 14, height: 1.45),
              decoration: const InputDecoration(
                hintText: 'Add a comment or ask K a question…',
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _QuestionChip(
                  selected: _isQuestion,
                  onTap: () => setState(() => _isQuestion = !_isQuestion),
                ),
                const Spacer(),
                FilledButton(
                  style: glossyPrimaryButton().copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    ),
                  ),
                  onPressed: _busy ? null : _post,
                  child: _busy
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Post', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(
                      color: KColors.negative, fontSize: 12)),
            ],
          ] else
            const Text(
              'Questions and comments are an Inner Circle feature.',
              style: TextStyle(
                fontSize: 12,
                color: KColors.memberTextSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// The question toggle as a quiet pill instead of a full Material switch —
/// gold when armed, hairline when not.
class _QuestionChip extends StatelessWidget {
  const _QuestionChip({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? KColors.memberAccent : KColors.memberTextSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? const Color(0x14C9A84C) : null,
          border: Border.all(
            color: selected ? const Color(0x59C9A84C) : KColors.memberBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              'Question for K',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends ConsumerStatefulWidget {
  const _CommentTile({
    super.key,
    required this.comment,
    required this.username,
    required this.insightId,
  });

  final Map<String, dynamic> comment;
  final String username;
  final String insightId;

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
  /// Non-null while the comment is being edited.
  TextEditingController? _edit;
  bool _busy = false;

  /// Mirrors the RLS author window; the server enforces it regardless.
  static const _authorWindow = Duration(hours: 48);

  Future<void> _saveEdit() async {
    final body = _edit!.text.trim();
    if (body.isEmpty) return;
    setState(() => _busy = true);
    try {
      await supabase
          .from('insight_comments')
          .update({'body': body}).eq('id', widget.comment['id'] as String);
      ref.invalidate(insightThreadProvider(widget.insightId));
      if (mounted) setState(() => _edit = null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this comment?'),
        content: const Text('It will be removed for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: KColors.negative),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await supabase
        .from('insight_comments')
        .delete()
        .eq('id', widget.comment['id'] as String);
    ref.invalidate(insightThreadProvider(widget.insightId));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final created = DateTime.tryParse(c['created_at'] as String? ?? '');
    final updated = DateTime.tryParse(c['updated_at'] as String? ?? '');
    final isQuestion = c['is_question'] == true;
    final isAdmin = ref.watch(isAdminProvider);
    final isOwn = c['user_id'] == supabase.auth.currentUser?.id;
    final inWindow = created != null &&
        DateTime.now().toUtc().difference(created.toUtc()) < _authorWindow;
    final canEdit = isOwn && (isAdmin || inWindow);
    final canDelete = isAdmin || (isOwn && inWindow);
    final wasEdited = created != null &&
        updated != null &&
        updated.difference(created).inSeconds > 1;
    final editing = _edit != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '@${widget.username}',
                style: KFonts.data(
                  size: 12,
                  weight: FontWeight.w600,
                  color: KColors.memberAccent,
                ),
              ),
              const SizedBox(width: 8),
              if (isQuestion)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0x14C9A84C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'QUESTION',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: KColors.memberAccent,
                    ),
                  ),
                ),
              if (wasEdited) ...[
                const SizedBox(width: 8),
                const Text(
                  '(edited)',
                  style: TextStyle(
                    fontSize: 11,
                    color: KColors.memberTextSecondary,
                  ),
                ),
              ],
              const Spacer(),
              if (created != null)
                Text(
                  DateFormat('MMM d, h:mm a').format(created.toLocal()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: KColors.memberTextSecondary,
                  ),
                ),
              if (canEdit && !editing) ...[
                const SizedBox(width: 4),
                _TinyIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit (within 48h)',
                  onTap: () => setState(() {
                    _edit = TextEditingController(text: c['body'] as String);
                  }),
                ),
              ],
              if (canDelete && !editing) ...[
                const SizedBox(width: 4),
                _TinyIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete (within 48h)',
                  onTap: () => _delete(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (editing) ...[
            TextField(
              controller: _edit,
              maxLines: 3,
              minLines: 1,
              maxLength: 2000,
              decoration: const InputDecoration(counterText: ''),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _edit = null),
                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _busy ? null : _saveEdit,
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 12, color: KColors.accent),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              c['body'] as String,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
        ],
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 14, color: KColors.memberTextSecondary),
        ),
      ),
    );
  }
}
