import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Temporary stand-in while feature pages are built out.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          color: KColors.memberTextSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}
