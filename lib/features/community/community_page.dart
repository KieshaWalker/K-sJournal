import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/glossy_card.dart';
import 'providers/community_providers.dart';
import 'widgets/edit_profile_dialog.dart';

/// The member directory: who is in the room, their face, their story, and
/// how many of K's trades they follow.
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
          constraints: const BoxConstraints(maxWidth: 1100),
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
                data: (data) => Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final p in data)
                      _ProfileCard(profile: p, isSelf: p['id'] == myId),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.fallbackInitial});

  final String? url;
  final String fallbackInitial;

  @override
  Widget build(BuildContext context) {
    final initial = Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: KGold.foil,
        shape: BoxShape.circle,
      ),
      child: Text(
        fallbackInitial,
        style: KFonts.heading(color: Colors.black, size: 22),
      ),
    );
    if (url == null || url!.isEmpty) return initial;
    return ClipOval(
      child: Image.network(
        url!,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => initial,
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
