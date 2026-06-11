import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import 'providers/invite_providers.dart';
import 'widgets/form_helpers.dart';

class InvitesPage extends ConsumerWidget {
  const InvitesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codes = ref.watch(inviteCodesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Invite Codes', style: KFonts.heading(size: 24)),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: KColors.accent,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Code'),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const InviteCodeFormDialog(),
                    ).then((_) => ref.invalidate(inviteCodesProvider)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              codes.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'Failed to load invite codes: $e',
                  style: const TextStyle(color: KColors.negative),
                ),
                data: (data) {
                  final pending = <Map<String, dynamic>>[];
                  final live = <Map<String, dynamic>>[];
                  final past = <Map<String, dynamic>>[];
                  for (final c in data) {
                    if (!inviteIsLive(c)) {
                      past.add(c);
                    } else if (c['approved_by_k'] == false) {
                      pending.add(c);
                    } else {
                      live.add(c);
                    }
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pending.isNotEmpty) ...[
                        _CodeSection(
                          title: 'Pending Your Approval',
                          codes: pending,
                          emptyText: '',
                        ),
                      ],
                      _CodeSection(
                        title: 'Active',
                        codes: live,
                        emptyText: 'No active codes. Mint one.',
                      ),
                      _CodeSection(
                        title: 'Expired & Used',
                        codes: past,
                        emptyText: 'Nothing here yet.',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeSection extends ConsumerWidget {
  const _CodeSection({
    required this.title,
    required this.codes,
    required this.emptyText,
  });

  final String title;
  final List<Map<String, dynamic>> codes;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${title.toUpperCase()} (${codes.length})',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: KColors.memberTextSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (codes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              emptyText,
              style: const TextStyle(
                color: KColors.memberTextSecondary,
                fontSize: 13,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Card(
              child: Column(
                children: [for (final c in codes) _CodeTile(code: c)],
              ),
            ),
          ),
      ],
    );
  }
}

class _CodeTile extends ConsumerWidget {
  const _CodeTile({required this.code});

  final Map<String, dynamic> code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = code;
    final live = inviteIsLive(c);
    final pending = live && c['approved_by_k'] == false;
    final tier = c['default_tier'] as String?;
    final notes = c['notes'] as String?;
    final maxUses = c['max_uses'] as int;
    final usesRemaining = c['uses_remaining'] as int;

    return ListTile(
      title: Row(
        children: [
          Text(c['code'] as String, style: KFonts.data(size: 14)),
          IconButton(
            tooltip: 'Copy code',
            icon: const Icon(Icons.copy, size: 14),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: c['code'] as String));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${c['code']} copied.')),
              );
            },
          ),
          _StatusChip(code: c),
        ],
      ),
      subtitle: Text(
        [
          tier == null ? 'member picks tier' : tierLabel(tier),
          '$usesRemaining of $maxUses uses left',
          _expiryText(c['expires_at'] as String?),
          if (notes != null && notes.isNotEmpty) notes,
        ].join('  ·  '),
        style: const TextStyle(fontSize: 12, height: 1.5),
      ),
      trailing: !live
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pending)
                  TextButton(
                    onPressed: () => _setApproved(ref, c),
                    child: const Text(
                      'Approve',
                      style:
                          TextStyle(fontSize: 12, color: KColors.positive),
                    ),
                  ),
                TextButton(
                  onPressed: () => _confirmRevoke(context, ref, c),
                  child: const Text(
                    'Revoke',
                    style: TextStyle(fontSize: 12, color: KColors.negative),
                  ),
                ),
              ],
            ),
    );
  }

  static String _expiryText(String? expiresAt) {
    if (expiresAt == null) return 'never expires';
    final expires = DateTime.parse(expiresAt).toLocal();
    final formatted = DateFormat('MMM d, yyyy').format(expires);
    final days = expires.difference(DateTime.now()).inDays;
    if (days < 0) return 'expired $formatted';
    if (days == 0) return 'expires today ($formatted)';
    return 'expires in ${days}d ($formatted)';
  }

  Future<void> _setApproved(WidgetRef ref, Map<String, dynamic> c) async {
    await supabase
        .from('invitation_codes')
        .update({'approved_by_k': true}).eq('id', c['id'] as String);
    ref.invalidate(inviteCodesProvider);
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> c,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revoke ${c['code']}?'),
        content: const Text(
            'The code stops working immediately. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Revoke',
              style: TextStyle(color: KColors.negative),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await supabase
          .from('invitation_codes')
          .update({'status': 'revoked'}).eq('id', c['id'] as String);
      ref.invalidate(inviteCodesProvider);
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.code});

  final Map<String, dynamic> code;

  @override
  Widget build(BuildContext context) {
    final live = inviteIsLive(code);
    final (label, color) = !live && code['status'] == 'active'
        // Status column lags the expiry date; show the truth.
        ? ('EXPIRED', KColors.pending)
        : switch (code['status'] as String) {
            'active' when code['approved_by_k'] == false => (
                'PENDING',
                KColors.pending
              ),
            'active' => ('ACTIVE', KColors.positive),
            'depleted' => ('USED UP', KColors.neutral),
            'revoked' => ('REVOKED', KColors.negative),
            _ => ('EXPIRED', KColors.pending),
          };
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: color,
        ),
      ),
    );
  }
}

String tierLabel(String tier) => switch (tier) {
      'observer' => 'Observer',
      'analyst' => 'Analyst',
      'inner_circle' => 'Inner Circle',
      _ => tier,
    };

// ---- New code dialog ----

class InviteCodeFormDialog extends StatefulWidget {
  const InviteCodeFormDialog({super.key});

  @override
  State<InviteCodeFormDialog> createState() => _InviteCodeFormDialogState();
}

class _InviteCodeFormDialogState extends State<InviteCodeFormDialog> {
  String _code = generateInviteCode();
  final _maxUses = TextEditingController(text: '1');
  final _notes = TextEditingController();
  String? _tier;
  int? _expiresDays = 30;
  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    final maxUses = int.tryParse(_maxUses.text.trim());
    if (maxUses == null || maxUses < 1 || maxUses > 100) {
      setState(() => _error = 'Max uses must be between 1 and 100.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.from('invitation_codes').insert({
        'code': _code,
        'created_by': supabase.auth.currentUser!.id,
        'default_tier': _tier,
        'max_uses': maxUses,
        'uses_remaining': maxUses,
        'expires_at': _expiresDays == null
            ? null
            : DateTime.now()
                .toUtc()
                .add(Duration(days: _expiresDays!))
                .toIso8601String(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } on Exception catch (e) {
      setState(() => _error = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormDialogShell(
      title: 'New Invite Code',
      submitLabel: 'Create Code',
      onSubmit: _save,
      error: _error,
      busy: _busy,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(_code, style: KFonts.data(size: 18)),
            ),
            IconButton(
              tooltip: 'Regenerate',
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () => setState(() => _code = generateInviteCode()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          initialValue: _tier,
          decoration: const InputDecoration(
            labelText: 'Tier',
            helperText: 'Locks the invitee to a tier, or let them pick.',
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('Member picks')),
            DropdownMenuItem(value: 'observer', child: Text('Observer')),
            DropdownMenuItem(value: 'analyst', child: Text('Analyst')),
            DropdownMenuItem(
                value: 'inner_circle', child: Text('Inner Circle')),
          ],
          onChanged: (v) => setState(() => _tier = v),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: NumField(controller: _maxUses, label: 'Max Uses'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: _expiresDays,
                decoration: const InputDecoration(labelText: 'Expires In'),
                items: const [
                  DropdownMenuItem(value: 7, child: Text('7 days')),
                  DropdownMenuItem(value: 14, child: Text('14 days')),
                  DropdownMenuItem(value: 30, child: Text('30 days')),
                  DropdownMenuItem(value: 90, child: Text('90 days')),
                  DropdownMenuItem(value: null, child: Text('Never')),
                ],
                onChanged: (v) => setState(() => _expiresDays = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(
            labelText: 'Notes',
            helperText: 'Who this is for. Only you see this.',
          ),
        ),
      ],
    );
  }
}
