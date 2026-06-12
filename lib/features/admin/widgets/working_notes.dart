import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../providers/admin_trade_providers.dart';

/// K's working notes on the workbench: levels to watch, reminders,
/// half-formed setups. Each note edits in place and deletes with a
/// confirm; the table is admin-only, so members never see any of it.
class WorkingNotesSection extends ConsumerStatefulWidget {
  const WorkingNotesSection({super.key});

  @override
  ConsumerState<WorkingNotesSection> createState() =>
      _WorkingNotesSectionState();
}

class _WorkingNotesSectionState extends ConsumerState<WorkingNotesSection> {
  final _draft = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _draft.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await supabase.from('admin_notes').insert({'body': text});
      _draft.clear();
      ref.invalidate(adminNotesProvider);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the note.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(adminNotesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WORKING NOTES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: KColors.memberTextSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _draft,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 4000,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                    decoration: const InputDecoration(
                      hintText: 'Note to self…',
                      counterText: '',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _add,
                  child: const Text('Add', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        notes.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => const Text(
            'Could not load notes.',
            style: TextStyle(color: KColors.negative, fontSize: 13),
          ),
          data: (rows) => rows.isEmpty
              ? const Text(
                  'Nothing on the pad.',
                  style: TextStyle(
                    color: KColors.memberTextSecondary,
                    fontSize: 13,
                  ),
                )
              : Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0)
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: const BoxDecoration(
                              gradient: KGold.hairline,
                            ),
                          ),
                        _NoteTile(
                          key: ValueKey(rows[i]['id']),
                          note: rows[i],
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _NoteTile extends ConsumerStatefulWidget {
  const _NoteTile({super.key, required this.note});

  final Map<String, dynamic> note;

  @override
  ConsumerState<_NoteTile> createState() => _NoteTileState();
}

class _NoteTileState extends ConsumerState<_NoteTile> {
  late final _body =
      TextEditingController(text: widget.note['body'] as String? ?? '');
  bool _editing = false;
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _body.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await supabase
          .from('admin_notes')
          .update({'body': text}).eq('id', widget.note['id'] as String);
      ref.invalidate(adminNotesProvider);
      if (mounted) setState(() => _editing = false);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the note.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this note?'),
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
    if (ok == true) {
      await supabase
          .from('admin_notes')
          .delete()
          .eq('id', widget.note['id'] as String);
      ref.invalidate(adminNotesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final updated = (widget.note['updated_at'] as String? ?? '');
    final date = updated.length >= 10 ? updated.substring(0, 10) : updated;

    if (_editing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _body,
              minLines: 1,
              maxLines: 8,
              maxLength: 4000,
              autofocus: true,
              style: const TextStyle(fontSize: 13, height: 1.5),
              decoration: const InputDecoration(
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0x33C9A84C)),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0x33C9A84C)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0x8CC9A84C)),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _body.text = widget.note['body'] as String? ?? '';
                            _editing = false;
                          }),
                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Save', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.note['body'] as String? ?? '',
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: KColors.memberTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit note',
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: () => setState(() => _editing = true),
          ),
          IconButton(
            tooltip: 'Delete note',
            icon: const Icon(Icons.delete_outline, size: 16),
            onPressed: _delete,
          ),
        ],
      ),
    );
  }
}
