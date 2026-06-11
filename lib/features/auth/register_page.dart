import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import 'widgets/auth_scaffold.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.inviteCodeId, this.defaultTier});

  final String? inviteCodeId;
  final String? defaultTier;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _agreedTerms = false;
  bool _agreedNotAdvice = false;
  bool? _usernameAvailable;
  String? _error;
  bool _busy = false;
  Timer? _debounce;

  static final _usernameRegex = RegExp(r'^[a-z0-9][a-z0-9_-]{2,19}$');

  void _checkUsername(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final candidate = value.trim().toLowerCase();
      if (!_usernameRegex.hasMatch(candidate)) {
        setState(() => _usernameAvailable = null);
        return;
      }
      final taken = await supabase
          .rpc('check_username_taken', params: {'p_username': candidate});
      if (mounted) setState(() => _usernameAvailable = taken != true);
    });
  }

  Future<void> _register() async {
    final username = _username.text.trim().toLowerCase();
    if (!_usernameRegex.hasMatch(username)) {
      setState(() => _error =
          'Username must be 3–20 chars: a-z, 0-9, _ or - (not leading).');
      return;
    }
    if (_password.text.length < 10) {
      setState(() => _error = 'Password must be at least 10 characters.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (!_agreedTerms || !_agreedNotAdvice) {
      setState(() => _error = 'Both acknowledgements are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {
          'username': username,
          if (widget.inviteCodeId != null)
            'invite_code_id': widget.inviteCodeId,
        },
      );
      if (mounted) {
        context.go('/auth/tier', extra: {'default_tier': widget.defaultTier});
      }
    } on Exception catch (e) {
      setState(() => _error = 'Registration failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      children: [
        TextField(
          controller: _username,
          decoration: InputDecoration(
            labelText: 'Username',
            helperText:
                'Public and visible to all members. Locked after 30 days.',
            suffixIcon: _usernameAvailable == null
                ? null
                : Icon(
                    _usernameAvailable! ? Icons.check : Icons.close,
                    color: _usernameAvailable!
                        ? KColors.positive
                        : KColors.negative,
                  ),
          ),
          onChanged: _checkUsername,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _email,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _password,
          decoration: const InputDecoration(
              labelText: 'Password', helperText: 'Minimum 10 characters'),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirm,
          decoration: const InputDecoration(labelText: 'Confirm Password'),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _agreedTerms,
          onChanged: (v) => setState(() => _agreedTerms = v ?? false),
          title: const Text('I agree to the Terms of Service',
              style: TextStyle(fontSize: 13)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _agreedNotAdvice,
          onChanged: (v) => setState(() => _agreedNotAdvice = v ?? false),
          title: const Text(
              'I understand this platform does not provide financial advice',
              style: TextStyle(fontSize: 13)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: KColors.negative, fontSize: 12)),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(
            label: 'Create Account', busy: _busy, onPressed: _register),
      ],
    );
  }
}
