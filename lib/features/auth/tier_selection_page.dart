import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import 'widgets/auth_scaffold.dart';

/// PAYMENTS ARE STUBBED (Phase 1): selecting a tier activates the membership
/// directly via the activate_membership_stub Edge Function. The real
/// payment rail replaces this in Phase 3.
class TierSelectionPage extends ConsumerStatefulWidget {
  const TierSelectionPage({super.key, this.defaultTier});

  final String? defaultTier;

  @override
  ConsumerState<TierSelectionPage> createState() => _TierSelectionPageState();
}

class _TierSelectionPageState extends ConsumerState<TierSelectionPage> {
  late String _selected = widget.defaultTier ?? Tiers.observer;
  bool _busy = false;
  String? _error;

  static const _tierInfo = [
    (
      tier: Tiers.observer,
      label: 'Observer',
      features: ['Dashboard', 'Macro data', 'In-flight', 'Landed P&L',
        'Band stats'],
    ),
    (
      tier: Tiers.analyst,
      label: 'Analyst',
      features: ['Everything in Observer', '+ Pre-flight', '+ Greeks',
        '+ IV data'],
    ),
    (
      tier: Tiers.innerCircle,
      label: 'Inner Circle',
      features: ['Everything in Analyst', '+ Sizing', '+ Community',
        '+ Early ideas'],
    ),
  ];

  Future<void> _activate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.functions.invoke(
        'activate_membership_stub',
        body: {'tier': _selected},
      );
      // Refresh the session so the new membership_tier claim is in the JWT.
      await supabase.auth.refreshSession();
      if (mounted) context.go('/auth/welcome');
    } on Exception {
      setState(() => _error = 'Activation failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 720,
      children: [
        const Text('Choose Your Tier',
            textAlign: TextAlign.center,
            style: TextStyle(color: KColors.authTextPrimary, fontSize: 20)),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final info in _tierInfo) ...[
              Expanded(
                child: _TierCard(
                  label: info.label,
                  price: Tiers.prices[info.tier]!,
                  features: info.features,
                  selected: _selected == info.tier,
                  onTap: () => setState(() => _selected = info.tier),
                ),
              ),
              if (info != _tierInfo.last) const SizedBox(width: 16),
            ],
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: KColors.negative, fontSize: 12)),
        ],
        const SizedBox(height: 32),
        AuthPrimaryButton(
            label: 'Continue', busy: _busy, onPressed: _activate),
        const SizedBox(height: 8),
        const Text(
          'Billing is not yet enabled — your membership activates immediately.',
          textAlign: TextAlign.center,
          style: TextStyle(color: KColors.authTextSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.label,
    required this.price,
    required this.features,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double price;
  final List<String> features;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? KColors.authBgElevated : KColors.authBgSurface,
          border: Border.all(
              color: selected ? KColors.accent : KColors.authBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    color: KColors.authTextPrimary, fontSize: 15)),
            const SizedBox(height: 8),
            Text('\$${price.toStringAsFixed(0)}/mo',
                style: const TextStyle(color: KColors.accent, fontSize: 18)),
            const SizedBox(height: 16),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(f,
                    style: const TextStyle(
                        color: KColors.authTextSecondary, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
