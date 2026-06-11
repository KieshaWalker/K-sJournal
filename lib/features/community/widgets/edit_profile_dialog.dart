import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase_client.dart';
import '../../admin/widgets/form_helpers.dart';

/// Edits the viewer's own profile row; RLS only permits updating your own.
/// Age shows on the directory computed from the birth date, which never
/// leaves the database.
class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key, required this.profile});

  /// The viewer's current public_profiles row; may be empty if unloaded.
  final Map<String, dynamic> profile;

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final _name =
      TextEditingController(text: widget.profile['display_name'] as String?);
  late final _avatar =
      TextEditingController(text: widget.profile['avatar_url'] as String?);
  late final _bio =
      TextEditingController(text: widget.profile['bio'] as String?);
  late final _location =
      TextEditingController(text: widget.profile['location'] as String?);
  DateTime? _birthDate;
  String? _error;
  bool _busy = false;

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (_bio.text.trim().length > 280) {
      setState(() => _error = 'Bio must be 280 characters or fewer.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? clean(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();
      final update = <String, dynamic>{
        'display_name': clean(_name),
        'avatar_url': clean(_avatar),
        'bio': clean(_bio),
        'location': clean(_location),
      };
      // Only write birth_date when the member picked one here, so an
      // untouched field never clears what is already saved.
      if (_birthDate != null) {
        final d = _birthDate!;
        update['birth_date'] = '${d.year}'
            '-${d.month.toString().padLeft(2, '0')}'
            '-${d.day.toString().padLeft(2, '0')}';
      }
      await supabase
          .from('users')
          .update(update)
          .eq('id', supabase.auth.currentUser!.id);
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
      title: 'Edit Profile',
      submitLabel: 'Save Profile',
      onSubmit: _save,
      error: _error,
      busy: _busy,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Display Name'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _avatar,
          decoration: const InputDecoration(
            labelText: 'Photo URL',
            helperText: 'A link to your profile photo.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _bio,
          maxLines: 3,
          maxLength: 280,
          decoration: const InputDecoration(labelText: 'Bio'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _location,
          decoration: const InputDecoration(
            labelText: 'Where You Are From',
            helperText: 'City, country — as much or little as you like.',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                _birthDate == null
                    ? widget.profile['age'] != null
                        ? 'Birth date set — age shows as '
                            '${widget.profile['age']}.'
                        : 'No birth date set.'
                    : 'Birth date: '
                        '${DateFormat('MMM d, yyyy').format(_birthDate!)}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _pickBirthDate,
              child: const Text('Set Birth Date'),
            ),
          ],
        ),
      ],
    );
  }
}
