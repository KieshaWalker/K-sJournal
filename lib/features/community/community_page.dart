import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/glossy_card.dart';
import 'providers/community_providers.dart';
import 'widgets/edit_profile_dialog.dart';
import 'widgets/member_avatar.dart';
import 'widgets/post_feed.dart';

/// The room, in two layers: a sideways rail of members ordered by who is
/// most active (tap a face for their full card), and the wall — member
/// posts in the X layout — below it.
class CommunityPage extends ConsumerWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(communityProfilesProvider);
    final myId = supabase.auth.currentUser?.id;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Community', style: KFonts.heading(size: 24)),
                        const SizedBox(height: 4),
                        const Text(
                          'The room. Invitation only.',
                          style: TextStyle(
                            fontSize: 13,
                            color: KColors.memberTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit My Profile'),
                    onPressed: () {
                      final mine = profiles.value?.where(
                        (p) => p['id'] == myId,
                      );
                      showDialog(
                        context: context,
                        builder: (_) => EditProfileDialog(
                          profile: (mine?.isEmpty ?? true)
                              ? const {}
                              : mine!.first,
                        ),
                      ).then(
                        (_) => ref.invalidate(communityProfilesProvider),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              profiles.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => const GlossyCard(
                  child: Text(
                    'Could not load the community.',
                    style: TextStyle(color: KColors.negative, fontSize: 13),
                  ),
                ),
                data: (data) {
                  final byActivity = [...data]..sort((a, b) {
                      final c = ((b['recent_activity'] as int?) ?? 0)
                          .compareTo((a['recent_activity'] as int?) ?? 0);
                      if (c != 0) return c;
                      if (a['is_admin'] == true && b['is_admin'] != true) {
                        return -1;
                      }
                      if (b['is_admin'] == true && a['is_admin'] != true) {
                        return 1;
                      }
                      return 0;
                    });
                  final profilesById = {
                    for (final p in data) p['id'] as String: p,
                  };
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MOST ACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: KColors.memberAccentHover,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ActiveRail(profiles: byActivity, myId: myId),
                      const SizedBox(height: 28),
                      Text('The Floor', style: KFonts.heading(size: 20)),
                      const SizedBox(height: 4),
                      const Text(
                        'Open talk between members.',
                        style: TextStyle(
                          fontSize: 13,
                          color: KColors.memberTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      PostFeed(profilesById: profilesById),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every member as a face in a sideways-scrolling rail, busiest first. The
/// host wears the foil ring; everyone else a gold hairline. Tap for the
/// full profile card.
class _ActiveRail extends StatelessWidget {
  const _ActiveRail({required this.profiles, required this.myId});

  final List<Map<String, dynamic>> profiles;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: profiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final p = profiles[i];
          final username = p['username'] as String? ?? 'member';
          final name = (p['display_name'] as String?)?.trim();
          final display = name?.isNotEmpty == true ? name! : '@$username';
          final isHost = p['is_admin'] == true;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: _ProfileCard(profile: p, isSelf: p['id'] == myId),
              ),
            ),
            child: SizedBox(
              width: 76,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isHost ? KGold.foil : null,
                      border: isHost
                          ? null
                          : Border.all(color: const Color(0x59C9A84C)),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: KColors.memberBgBase,
                      ),
                      child: MemberAvatar(
                        url: p['avatar_url'] as String?,
                        fallbackInitial: username[0].toUpperCase(),
                        size: 54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xE8FFFDF8),
                    ),
                  ),
                  if (isHost)
                    const Text(
                      'HOST',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: KColors.memberAccentHover,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.isSelf});

  final Map<String, dynamic> profile;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final username = p['username'] as String? ?? 'member';
    final name = (p['display_name'] as String?)?.trim();
    final bio = (p['bio'] as String?)?.trim();
    final location = (p['location'] as String?)?.trim();
    final age = p['age'] as int?;
    final followed = (p['trades_followed'] as int?) ?? 0;
    final isHost = p['is_admin'] == true;
    final since = DateTime.tryParse(p['member_since'] as String? ?? '');

    return GlossyCard(
      width: 348,
      padding: const EdgeInsets.all(20),
      hoverLift: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MemberAvatar(
                url: p['avatar_url'] as String?,
                fallbackInitial:
                    (name?.isNotEmpty == true ? name! : username)[0]
                        .toUpperCase(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name?.isNotEmpty == true ? name! : '@$username',
                      style: KFonts.heading(size: 17),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username${isSelf ? '  ·  you' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: KColors.memberTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _TierBadge(
                isHost: isHost,
                tier: p['membership_tier'] as String?,
              ),
            ],
          ),
          if (bio?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              bio!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (location?.isNotEmpty == true)
                _Fact(Icons.place_outlined, location!),
              if (age != null) _Fact(Icons.cake_outlined, '$age'),
              _Fact(
                Icons.push_pin_outlined,
                '$followed trade${followed == 1 ? '' : 's'} followed',
              ),
              if (since != null)
                _Fact(Icons.schedule_outlined, 'Joined ${since.year}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.isHost, required this.tier});

  final bool isHost;
  final String? tier;

  @override
  Widget build(BuildContext context) {
    final label = isHost
        ? 'HOST'
        : switch (tier) {
            'observer' => 'OBSERVER',
            'analyst' => 'ANALYST',
            'inner_circle' => 'INNER CIRCLE',
            _ => null,
          };
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x59C9A84C)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: KColors.memberAccentHover,
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: KColors.memberTextSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: KColors.memberTextSecondary,
          ),
        ),
      ],
    );
  }
}
