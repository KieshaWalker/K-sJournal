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
                Text(
                  "K's Journal",
                  textAlign: TextAlign.center,
                  style: KFonts.wordmark(KColors.accent),
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
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: const RoundedRectangleBorder(),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              label.toUpperCase(),
              style: const TextStyle(fontSize: 12, letterSpacing: 2.5),
            ),
    );
  }
}
