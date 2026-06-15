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
    (label: 'Community', path: '/community'),
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
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: const BoxDecoration(
                color: KColors.memberBgSurface,
                border:
                    Border(bottom: BorderSide(color: Color(0x26C9A84C))),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              // Below the breakpoint the inline links overflow the row,
              // so they collapse into a popup menu instead.
              child: LayoutBuilder(builder: (context, constraints) {
                final compact = constraints.maxWidth < 880;
                return Row(
                  children: [
                    // Gold-foil wordmark — gradient leaf, not flat color.
                    // Shadow lives on a layer behind the mask: srcIn would
                    // tint an in-style shadow gold.
                    Stack(
                      children: [
                        Text(
                          "K's Journal",
                          style: KFonts.wordmark(Colors.transparent).copyWith(
                              fontSize: 30, shadows: KShadows.wordmark),
                        ),
                        ShaderMask(
                          shaderCallback: KGold.foilShader,
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            "K's Journal",
                            style: KFonts.wordmark(Colors.white)
                                .copyWith(fontSize: 30),
                          ),
                        ),
                      ],
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 52,),
                      for (final link in _links)
                        _NavLink(
                          label: link.label,
                          active: location.startsWith(link.path),
                          onTap: () => context.go(link.path),
                        ),
                      if (isAdmin)
                        PopupMenuButton<String>(
                          tooltip: 'Admin',
                          onSelected: (path) => context.go(path),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: '/admin/trade',
                                child: Text('Trade Entry')),
                            PopupMenuItem(
                                value: '/admin/invites',
                                child: Text('Invite Codes')),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: const Color(0x59C9A84C)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'ADMIN  ▾',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600,
                                color: KColors.memberAccent,
                              ),
                            ),
                          ),
                        ),
                    ],
                    const Spacer(),
                    if (compact)
                      PopupMenuButton<String>(
                        tooltip: 'Menu',
                        onSelected: (path) => context.go(path),
                        itemBuilder: (_) => [
                          for (final link in _links)
                            PopupMenuItem(
                              value: link.path,
                              child: Text(
                                link.label,
                                style: TextStyle(
                                  fontWeight: location.startsWith(link.path)
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          if (isAdmin) ...[
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                                value: '/admin/trade',
                                child: Text('Trade Entry')),
                            const PopupMenuItem(
                                value: '/admin/invites',
                                child: Text('Invite Codes')),
                          ],
                        ],
                        // A gold-hairline pill so the menu reads as a real
                        // control, not stray icon lines on the cream bar.
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0x14C9A84C),
                            border:
                                Border.all(color: const Color(0x59C9A84C)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.menu_rounded,
                            size: 22,
                            color: KColors.memberTextPrimary,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: '',
                      onSelected: (v) async {
                        if (v == 'settings') context.go('/settings');
                        if (v == 'signout') {
                          await supabase.auth.signOut();
                          if (context.mounted) context.go('/');
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'settings', child: Text('Settings')),
                        PopupMenuItem(
                            value: 'signout', child: Text('Sign Out')),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              gradient: KGold.foil,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              username.isEmpty
                                  ? '?'
                                  : username[0].toUpperCase(),
                              style: KFonts.heading(
                                  color: Colors.black, size: 14),
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(width: 10),
                            Text(
                              '@$username',
                              style: const TextStyle(
                                fontSize: 13,
                                color: KColors.memberTextSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
            // Content sits under a faint top-lit gold wash — showroom light.
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -1.2),
                    radius: 1.6,
                    colors: [Color(0x12C9A84C), Color(0x00C9A84C)],
                  ),
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 36),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.8,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active
                    ? KColors.memberTextPrimary
                    : KColors.memberTextSecondary,
                shadows: KShadows.text,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 2,
              width: active ? 24 : 0,
              decoration: const BoxDecoration(gradient: KGold.foil),
            ),
          ],
        ),
      ),
    );
  }
}
