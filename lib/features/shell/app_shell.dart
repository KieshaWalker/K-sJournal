import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';

/// Cream-theme shell with the top nav bar, wrapping all member pages.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _links = [
    (label: 'Dashboard', path: '/dashboard'),
    (label: 'In-Flight', path: '/positions'),
    (label: 'Pre-Flight', path: '/ideas'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(usernameProvider) ?? 'member';
    final isAdmin = ref.watch(isAdminProvider);
    final location = GoRouterState.of(context).matchedLocation;

    return Theme(
      data: buildMemberTheme(),
      child: Scaffold(
        backgroundColor: KColors.memberBgBase,
        body: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: KColors.memberBgSurface,
                border:
                    Border(bottom: BorderSide(color: KColors.memberBorder)),
              ),
              child: Row(
                children: [
                  Text(
                    "K's Journal",
                    style: KFonts.wordmark(KColors.accent).copyWith(fontSize: 30),
                  ),
                  const SizedBox(width: 48),
                  for (final link in _links)
                    Padding(
                      padding: const EdgeInsets.only(right: 32),
                      child: InkWell(
                        onTap: () => context.go(link.path),
                        child: Text(
                          link.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: location.startsWith(link.path)
                                ? KColors.memberTextPrimary
                                : KColors.memberTextSecondary,
                            fontWeight: location.startsWith(link.path)
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  if (isAdmin)
                    PopupMenuButton<String>(
                      onSelected: (path) => context.go(path),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: '/admin/trade', child: Text('Trade Entry')),
                        PopupMenuItem(
                            value: '/admin/invites',
                            child: Text('Invite Codes')),
                      ],
                      child: const Text('Admin ▾',
                          style: TextStyle(
                              fontSize: 13, color: KColors.accent)),
                    ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'settings') context.go('/settings');
                      if (v == 'signout') {
                        await supabase.auth.signOut();
                        if (context.mounted) context.go('/');
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'settings', child: Text('Settings')),
                      PopupMenuItem(value: 'signout', child: Text('Sign Out')),
                    ],
                    child: Text('@$username',
                        style: const TextStyle(
                            fontSize: 13,
                            color: KColors.memberTextSecondary)),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
