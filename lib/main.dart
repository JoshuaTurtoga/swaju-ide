import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'providers/ide_providers.dart';

/// Entry point for Swaju IDE.
///
/// Wraps the app in a Riverpod [ProviderScope] so every widget in the tree
/// can read / watch providers without manual dependency wiring.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SwajuIdeApp()));
}

class SwajuIdeApp extends ConsumerWidget {
  const SwajuIdeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeProvider);
    final theme = AppTheme.fromType(themeType);

    return MaterialApp(
      title: 'Swaju IDE',
      debugShowCheckedModeBanner: false,
      theme: theme.themeData,
      home: const HomeScreen(),
    );
  }
}
