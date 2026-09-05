import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../providers/ide_providers.dart';
import '../theme/app_theme.dart';
import 'custom_dropdown.dart';

/// Top toolbar for the IDE.
///
/// Contains: language selector dropdown, Run button, Kill button, and a
/// status indicator showing the current execution state.
class Toolbar extends ConsumerWidget {
  /// Called when the user clicks Run.
  final VoidCallback onRun;

  /// Called when the user clicks Kill.
  final VoidCallback onKill;

  const Toolbar({super.key, required this.onRun, required this.onKill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeProvider);
    final theme = AppTheme.fromType(themeType);
    final selectedLang = ref.watch(selectedLanguageProvider);
    final execState = ref.watch(executionStateProvider);
    final isRunning = execState != ExecutionState.idle;

    return Container(
      height: 64,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: theme.neumorphicOuter(),
      child: Row(
        children: [
          // ── App icon / title ──
          Icon(Icons.code_rounded, color: theme.accent, size: 22),
          const SizedBox(width: 8),
          Text(
            'Swaju IDE',
            style: theme.uiText.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(width: 24),

          // ── Language dropdown ──
          CustomDropdown<ProgrammingLanguage>(
            theme: theme,
            value: selectedLang,
            items: ProgrammingLanguage.values.map((lang) {
              return CustomDropdownItem(
                value: lang,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _langIcon(lang),
                    const SizedBox(width: 8),
                    Text(
                      lang.displayName,
                      style: theme.uiText.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (lang) {
              if (lang != null) {
                ref.read(selectedLanguageProvider.notifier).state = lang;
              }
            },
          ),

          const SizedBox(width: 16),

          // ── Run button ──
          _ToolbarButton(
            icon: Icons.play_arrow_rounded,
            label: 'Run',
            color: theme.success,
            onPressed: isRunning ? null : onRun,
            tooltip: 'Compile & Run (F5)',
          ),

          const SizedBox(width: 8),

          // ── Kill button ──
          _ToolbarButton(
            icon: Icons.stop_rounded,
            label: 'Kill',
            color: theme.error,
            onPressed: isRunning ? onKill : null,
            tooltip: 'Kill running process (F6)',
          ),

          const SizedBox(width: 16),

          // ── Status indicator ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _statusChip(execState, theme),
          ),

          const Spacer(),

          // ── Theme dropdown ──
          CustomDropdown<AppThemeType>(
            theme: theme,
            value: themeType,
            items: AppThemeType.values.map((type) {
              return CustomDropdownItem(
                value: type,
                selectedChild: Icon(Icons.palette_rounded, color: theme.textSecondary, size: 16),
                child: Text(
                  type.displayName,
                  style: theme.uiText.copyWith(fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (type) {
              if (type != null) {
                ref.read(themeProvider.notifier).state = type;
              }
            },
          ),
          
          const SizedBox(width: 16),

          // ── AI status ──
          Consumer(builder: (context, ref, _) {
            final aiLoaded = ref.watch(aiLoadedProvider);
            return Tooltip(
              message: aiLoaded
                  ? 'AI assistant loaded'
                  : 'AI not available — place a .gguf model in the models directory',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 16,
                    color: aiLoaded ? theme.info : theme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'AI',
                    style: theme.uiTextSmall.copyWith(
                      color: aiLoaded ? theme.info : theme.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _langIcon(ProgrammingLanguage lang) {
    final iconMap = {
      ProgrammingLanguage.c: 'https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/c/c-original.svg',
      ProgrammingLanguage.cpp: 'https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/cplusplus/cplusplus-original.svg',
      ProgrammingLanguage.csharp: 'https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/csharp/csharp-original.svg',
      ProgrammingLanguage.java: 'https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/java/java-original.svg',
      ProgrammingLanguage.python: 'https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/python/python-original.svg',
    };
    
    return SvgPicture.network(
      iconMap[lang]!,
      width: 18,
      height: 18,
      placeholderBuilder: (context) => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _statusChip(ExecutionState state, AppTheme theme) {
    switch (state) {
      case ExecutionState.idle:
        return Row(
          key: const ValueKey('idle'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Text('Ready', style: theme.uiTextSmall),
          ],
        );
      case ExecutionState.compiling:
        return Row(
          key: const ValueKey('compiling'),
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.warning,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Compiling…',
              style: theme.uiTextSmall.copyWith(color: theme.warning),
            ),
          ],
        );
      case ExecutionState.running:
        return Row(
          key: const ValueKey('running'),
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.success,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Running…',
              style: theme.uiTextSmall.copyWith(color: theme.success),
            ),
          ],
        );
    }
  }
}

// ─── Toolbar button ──────────────────────────────────────────────────────────
class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final String tooltip;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.fromType(ProviderScope.containerOf(context).read(themeProvider));
    final enabled = widget.onPressed != null;
    final color = enabled ? widget.color : widget.color.withValues(alpha: 0.3);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: (_) => enabled ? setState(() => _pressed = true) : null,
          onTapUp: (_) => enabled ? setState(() => _pressed = false) : null,
          onTapCancel: () => enabled ? setState(() => _pressed = false) : null,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: _pressed
                ? theme.neumorphicInner(radius: 8)
                : theme.neumorphicOuter(radius: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: theme.uiText.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

