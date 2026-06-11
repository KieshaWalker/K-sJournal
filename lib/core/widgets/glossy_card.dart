import 'package:flutter/material.dart';

import '../theme.dart';

/// The standard surface for everything below the nav in the member app:
/// rounded corners, a white-to-cream sheen, hairline gold border, and a
/// soft drop shadow. No sharp edges.
class GlossyCard extends StatelessWidget {
  const GlossyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 16,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double? width;

  static BoxDecoration decoration({double radius = 16}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFFBF6EB)],
        ),
        border: Border.all(color: const Color(0x2EC9A84C)), // gold at 18%
        boxShadow: const [
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
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding,
      decoration: decoration(radius: radius),
      child: child,
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
