import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../providers/ide_providers.dart';
import '../theme/app_theme.dart';

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
    final selectedLang = ref.watch(selectedLanguageProvider);
    final execState = ref.watch(executionStateProvider);
    final isRunning = execState != ExecutionState.idle;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppTheme.glassSurface,
            border: Border(
              bottom: BorderSide(color: AppTheme.glassBorder, width: 1),
            ),
          ),
          child: Row(
            children: [
          // ── App icon / title ──
          Icon(Icons.code_rounded, color: AppTheme.accent, size: 22),
          const SizedBox(width: 8),
          Text(
            'Swaju IDE',
            style: AppTheme.uiText.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 24),

          // ── Language dropdown ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.panelBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ProgrammingLanguage>(
                value: selectedLang,
                dropdownColor: AppTheme.surfaceVariant,
                style: AppTheme.uiText.copyWith(fontSize: 13),
                icon: Icon(
                  Icons.expand_more_rounded,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
                items: ProgrammingLanguage.values.map((lang) {
                  return DropdownMenuItem(
                    value: lang,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _langIcon(lang),
                        const SizedBox(width: 8),
                        Text(lang.displayName),
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
            ),
          ),

          const SizedBox(width: 16),

          // ── Run button ──
          _ToolbarButton(
            icon: Icons.play_arrow_rounded,
            label: 'Run',
            color: AppTheme.success,
            onPressed: isRunning ? null : onRun,
            tooltip: 'Compile & Run (F5)',
          ),

          const SizedBox(width: 8),

          // ── Kill button ──
          _ToolbarButton(
            icon: Icons.stop_rounded,
            label: 'Kill',
            color: AppTheme.error,
            onPressed: isRunning ? onKill : null,
            tooltip: 'Kill running process (F6)',
          ),

          const SizedBox(width: 16),

          // ── Status indicator ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _statusChip(execState),
          ),

          const Spacer(),

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
                    color: aiLoaded ? AppTheme.info : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'AI',
                    style: AppTheme.uiTextSmall.copyWith(
                      color: aiLoaded ? AppTheme.info : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    )));
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

  Widget _statusChip(ExecutionState state) {
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
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Text('Ready', style: AppTheme.uiTextSmall),
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
                color: AppTheme.warning,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Compiling…',
              style: AppTheme.uiTextSmall.copyWith(color: AppTheme.warning),
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
                color: AppTheme.success,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Running…',
              style: AppTheme.uiTextSmall.copyWith(color: AppTheme.success),
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

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color = enabled ? widget.color : widget.color.withValues(alpha: 0.3);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _hovered && enabled
                  ? color.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _hovered && enabled ? color : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 18, color: color),
                const SizedBox(width: 4),
                Text(
                  widget.label,
                  style: AppTheme.uiText.copyWith(
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
