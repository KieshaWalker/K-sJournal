import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.authBgBase,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "K's Journal",
              style: TextStyle(
                color: KColors.accent,
                fontSize: 18,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 64),
            SizedBox(
              width: 240,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: KColors.authTextPrimary,
                  side: const BorderSide(color: KColors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => context.go('/login'),
                child: const Text("I'm a Member"),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go('/auth/invite'),
              child: const Text(
                "New to K's Journal",
                style: TextStyle(color: KColors.authTextSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
