import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import 'widgets/auth_scaffold.dart';

class InviteCodePage extends StatefulWidget {
  const InviteCodePage({super.key});

  @override
  State<InviteCodePage> createState() => _InviteCodePageState();
}

class _InviteCodePageState extends State<InviteCodePage> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _validate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await supabase.functions.invoke(
        'validate_invite_code',
        body: {'code': _code.text.trim().toUpperCase()},
      );
      final data = res.data as Map<String, dynamic>;
      if (mounted) {
        context.go('/auth/register', extra: {
          'invite_code_id': data['invite_code_id'],
          'default_tier': data['default_tier'],
        });
      }
    } on Exception {
      setState(() => _error = 'Invalid or expired invitation code.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      children: [
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          decoration:
              const InputDecoration(labelText: 'Enter your invitation code'),
          onSubmitted: (_) => _validate(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: KColors.negative, fontSize: 12)),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(label: 'Continue', busy: _busy, onPressed: _validate),
      ],
    );
  }
}
