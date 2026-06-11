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
            Text(
              "K's Journal",
              style: KFonts.wordmark(KColors.accent).copyWith(fontSize: 44),
            ),
            const SizedBox(height: 20),
            Container(width: 64, height: 1, color: KColors.accent),
            const SizedBox(height: 20),
            const Text(
              'A  P R I V A T E   T R A D I N G   R E C O R D',
              style: TextStyle(
                color: KColors.authTextSecondary,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 88),
            SizedBox(
              width: 260,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: KColors.authTextPrimary,
                  side: const BorderSide(color: KColors.accent, width: 0.8),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: const RoundedRectangleBorder(),
                ),
                onPressed: () => context.go('/login'),
                child: const Text(
                  "I'M A MEMBER",
                  style: TextStyle(fontSize: 12, letterSpacing: 2.5),
                ),
              ),
            ),
            const SizedBox(height: 28),
            TextButton(
              onPressed: () => context.go('/auth/invite'),
              child: const Text(
                'I  H A V E   A N   I N V I T A T I O N',
                style: TextStyle(
                  color: KColors.authTextSecondary,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
