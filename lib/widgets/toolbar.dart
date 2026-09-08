import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:google_fonts/google_fonts.dart';

import '../providers/ide_providers.dart';
import '../theme/app_theme.dart';

/// Top toolbar for the IDE.
///
/// Contains: language selector dropdown, Run button, Kill button,
/// a Convert Code button (Feature 3), and a status indicator.
class Toolbar extends ConsumerWidget {
  /// Called when the user clicks Run.
  final VoidCallback onRun;

  /// Called when the user clicks Kill.
  final VoidCallback onKill;

  /// Called when the user clicks Convert Code (opens language dialog).
  final VoidCallback onConvert;

  const Toolbar({
    super.key,
    required this.onRun,
    required this.onKill,
    required this.onConvert,
  });

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
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                './ACE',
                style: GoogleFonts.zenDots(
                  fontSize: 28,
                  height: 1.0,
                  letterSpacing: -1.0,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Local AI Compiler Engine',
                style: theme.uiTextSmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),

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

          const SizedBox(width: 8),

          // ── Convert Code button (Feature 3) ──
          Consumer(builder: (context, ref, _) {
            final aiLoaded = ref.watch(aiLoadedProvider);
            return _ToolbarButton(
              icon: Icons.swap_horiz_rounded,
              label: 'Convert',
              color: theme.info,
              onPressed: (aiLoaded && !isRunning) ? onConvert : null,
              tooltip: aiLoaded
                  ? 'Convert code to another language'
                  : 'AI not connected — cannot convert',
            );
          }),

          const SizedBox(width: 16),

          // ── Status indicator ──
          Consumer(builder: (context, ref, _) {
            final isAnalyzing = ref.watch(isAiAnalyzingProvider);
            final isConverting = ref.watch(isConvertingProvider);
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _statusChip(execState, isAnalyzing, isConverting, theme),
            );
          }),

          const Spacer(),

          // ── Language dropdown (right side) ──
          DropdownMenu<ProgrammingLanguage>(
            key: ValueKey(selectedLang),
            initialSelection: selectedLang,
            width: 170,
            leadingIcon: Padding(
              padding: const EdgeInsets.only(left: 12.0, right: 8.0),
              child: _langIcon(selectedLang),
            ),
            textStyle: theme.uiText.copyWith(fontSize: 13),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              filled: true,
              fillColor: theme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              isDense: true,
              constraints: const BoxConstraints(maxHeight: 38),
            ),
            menuStyle: MenuStyle(
              visualDensity: VisualDensity.standard,
              backgroundColor: WidgetStatePropertyAll(theme.surface),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: theme.panelBorder))),
            ),
            dropdownMenuEntries: ProgrammingLanguage.values.map((lang) => DropdownMenuEntry(
              value: lang,
              label: lang.displayName,
              leadingIcon: Padding(
                padding: const EdgeInsets.only(right: 8.0, left: 4.0),
                child: _langIcon(lang),
              ),
            )).toList(),
            onSelected: (lang) {
              if (lang != null) {
                ref.read(selectedLanguageProvider.notifier).state = lang;
              }
            },
          ),

          const SizedBox(width: 12),

          // ── Theme toggle (light / dark) ──
          ThemeToggleButton(theme: theme, themeType: themeType),

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

  Widget _statusChip(
      ExecutionState state, bool isAnalyzing, bool isConverting, AppTheme theme) {
    if (isConverting) {
      return Row(
        key: const ValueKey('ai_converting'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(theme.info),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Converting…',
            style: theme.uiTextSmall
                .copyWith(color: theme.info, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    if (isAnalyzing) {
      return Row(
        key: const ValueKey('ai_analyzing'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(theme.info),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'AI Analyzing…',
            style: theme.uiTextSmall
                .copyWith(color: theme.info, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.fromType(ProviderScope.containerOf(context).read(themeProvider));
    final enabled = widget.onPressed != null;
    final color = enabled ? widget.color : widget.color.withValues(alpha: 0.3);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onExit: (_) => setState(() => _pressed = false),
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

// ─── Theme toggle button ─────────────────────────────────────────────────────
class ThemeToggleButton extends ConsumerStatefulWidget {
  final AppTheme theme;
  final AppThemeType themeType;

  const ThemeToggleButton({
    super.key,
    required this.theme,
    required this.themeType,
  });

  @override
  ConsumerState<ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends ConsumerState<ThemeToggleButton> {
  Future<void> _toggle() async {
    final isDark = widget.themeType == AppThemeType.darkSlate;
    final nextType =
        isDark ? AppThemeType.neumorphismWhite : AppThemeType.darkSlate;
    final currentTheme = AppTheme.fromType(widget.themeType);
    final nextTheme = AppTheme.fromType(nextType);

    // Get centre of this button in global coordinates.
    final renderBox = context.findRenderObject() as RenderBox?;
    
    // Capture snapshot of the current UI
    final rootKey = ref.read(rootBoundaryKeyProvider);
    ui.Image? snapshot;
    if (rootKey.currentContext != null) {
      final boundary = rootKey.currentContext!.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        snapshot = await boundary.toImage(pixelRatio: MediaQuery.of(context).devicePixelRatio);
      }
    }

    if (renderBox != null) {
      final origin =
          renderBox.localToGlobal(renderBox.size.center(Offset.zero));

      // Trigger background reveal animation behind window contents
      ref.read(themeTransitionEventProvider.notifier).state =
          ThemeTransitionEvent(
        origin: origin,
        fromColor: currentTheme.background,
        toColor: nextTheme.background,
        eventId: DateTime.now().microsecondsSinceEpoch,
        image: snapshot,
      );
    }

    // Switch theme immediately
    ref.read(themeProvider.notifier).state = nextType;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = widget.themeType == AppThemeType.neumorphismWhite;

    return Tooltip(
      message: isLight ? 'Switch to Dark Mode' : 'Switch to Light Mode',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: widget.theme.neumorphicOuter(radius: 8),
            child: _AnimatedLightbulbIcon(
              isOn: isLight,
              theme: widget.theme,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Animated Lightbulb Icon ──────────────────────────────────────────────────
class _AnimatedLightbulbIcon extends StatefulWidget {
  final bool isOn;
  final AppTheme theme;

  const _AnimatedLightbulbIcon({
    required this.isOn,
    required this.theme,
  });

  @override
  State<_AnimatedLightbulbIcon> createState() => _AnimatedLightbulbIconState();
}

class _AnimatedLightbulbIconState extends State<_AnimatedLightbulbIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: widget.isOn ? 1.0 : 0.0,
    );

    _glowAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInBack)),
        weight: 55,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _AnimatedLightbulbIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOn != oldWidget.isOn) {
      if (widget.isOn) {
        _controller.forward(from: 0.0);
      } else {
        _controller.reverse(from: 1.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _glowAnim.value; // 0.0 = OFF, 1.0 = ON
        final bulbColor = Color.lerp(
          widget.theme.textMuted,
          const Color(0xFFFFB000),
          t,
        )!;

        return SizedBox(
          width: 22,
          height: 22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Radial warm glow when turning ON / lit
              if (t > 0.01)
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB000).withValues(alpha: 0.55 * t),
                        blurRadius: 10 * t,
                        spreadRadius: 2 * t,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFE082).withValues(alpha: 0.3 * t),
                        blurRadius: 16 * t,
                        spreadRadius: 4 * t,
                      ),
                    ],
                  ),
                ),

              // Lightbulb icon with spring scale & crossfade
              Transform.scale(
                scale: _scaleAnim.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Off bulb (dim outline)
                    Opacity(
                      opacity: (1.0 - t).clamp(0.0, 1.0),
                      child: Icon(
                        Icons.lightbulb_outline_rounded,
                        key: const ValueKey('bulb_off'),
                        color: widget.theme.textMuted,
                        size: 19,
                      ),
                    ),
                    // On bulb (bright golden filled)
                    Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Icon(
                        Icons.lightbulb_rounded,
                        key: const ValueKey('bulb_on'),
                        color: bulbColor,
                        size: 19,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Circular reveal painter ──────────────────────────────────────────────────
class CircleRevealPainter extends CustomPainter {
  final double progress;
  final Offset origin;
  final Color color;

  const CircleRevealPainter({
    required this.progress,
    required this.origin,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Radius grows to reach the farthest corner from the origin.
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    final maxRadius = corners
        .map((c) => (c - origin).distance)
        .reduce((a, b) => a > b ? a : b);

    canvas.drawCircle(
      origin,
      maxRadius * progress,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(CircleRevealPainter old) =>
      old.progress != progress || old.color != color;
}

