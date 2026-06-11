import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Shared black/gold scaffold for all auth-shell screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.children, this.maxWidth = 360});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.authBgBase,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "K's Journal",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: KColors.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 48),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: KColors.accent,
        foregroundColor: KColors.authBgBase,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
