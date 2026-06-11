import 'package:flutter/material.dart';

import '../theme.dart';

/// The standard surface for everything below the nav in the member app:
/// rounded corners, a white-to-cream sheen, hairline gold border, a soft
/// drop shadow — and a quiet lift toward the cursor on hover. No sharp
/// edges, nothing static.
class GlossyCard extends StatefulWidget {
  const GlossyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 16,
    this.width,
    this.hoverLift = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double? width;
  final bool hoverLift;

  static BoxDecoration decoration({double radius = 16, bool hovered = false}) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFFBF6EB)],
        ),
        border: Border.all(
          color: hovered ? const Color(0x59C9A84C) : const Color(0x2EC9A84C),
        ),
        boxShadow: hovered
            ? const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
                BoxShadow(
                  color: Color(0x1AC9A84C),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: Color(0x0FC9A84C),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
      );

  @override
  State<GlossyCard> createState() => _GlossyCardState();
}

class _GlossyCardState extends State<GlossyCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final lifted = widget.hoverLift && _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: widget.width,
        padding: widget.padding,
        transform: Matrix4.translationValues(0, lifted ? -3 : 0, 0),
        decoration:
            GlossyCard.decoration(radius: widget.radius, hovered: lifted),
        child: widget.child,
      ),
    );
  }
}

/// Glossy gold-filled pill for primary actions in the member app.
ButtonStyle glossyPrimaryButton() => FilledButton.styleFrom(
      backgroundColor: KColors.accent,
      foregroundColor: Colors.black,
      elevation: 2,
      shadowColor: const Color(0x66C9A84C),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: const StadiumBorder(),
    );
