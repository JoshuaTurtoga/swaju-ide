import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

/// Entry point for Swaju IDE.
///
/// Wraps the app in a Riverpod [ProviderScope] so every widget in the tree
/// can read / watch providers without manual dependency wiring.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SwajuIdeApp()));
}

class SwajuIdeApp extends StatelessWidget {
  const SwajuIdeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swaju IDE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
