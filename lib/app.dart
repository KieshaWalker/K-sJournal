import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'core/router.dart';
import 'core/theme.dart';

class KJournalApp extends ConsumerWidget {
  const KJournalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: appName,
      debugShowCheckedModeBanner: false,
      // Auth shell theme is the default; AppShell wraps member pages in the
      // cream member theme.
      theme: buildAuthTheme(),
      routerConfig: router,
    );
  }
}
