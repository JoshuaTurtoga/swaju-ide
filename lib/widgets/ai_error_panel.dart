import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ide_providers.dart';
import '../theme/app_theme.dart';

/// Feature 1 -- Cryptic Error Translator
///
/// A persistent, styled diagnostic card that sits between the code editor
/// and the terminal panel. It is only visible when [aiDiagnosisProvider]
/// is non-null (i.e., the last run produced stderr and the AI has
/// generated or is generating an explanation).
///
/// Layout:
///   +--------------------------------------------------+
///   |  robot icon  AI Diagnosis         [collapse] [x] |
///   +--------------------------------------------------+
///   |  <streamed AI explanation text>                  |
///   +--------------------------------------------------+
class AiErrorPanel extends ConsumerStatefulWidget {
  const AiErrorPanel({super.key});

  @override
  ConsumerState<AiErrorPanel> createState() => _AiErrorPanelState();
}

class _AiErrorPanelState extends ConsumerState<AiErrorPanel>
    with SingleTickerProviderStateMixin {
  bool _collapsed = false;
  late AnimationController _controller;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _heightFactor = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCollapse() {
    setState(() => _collapsed = !_collapsed);
    if (_collapsed) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  void _dismiss() {
    ref.read(aiDiagnosisProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final diagnosis = ref.watch(aiDiagnosisProvider);
    final theme = AppTheme.fromType(ref.watch(themeProvider));

    if (diagnosis == null) return const SizedBox.shrink();

    final borderColor = theme.info.withValues(alpha: 0.35);
    final headerColor = theme.info.withValues(alpha: 0.10);

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF1A2535)
              : const Color(0xFFEFF6FF),
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: theme.info.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header bar
            GestureDetector(
              onTap: _toggleCollapse,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(10),
                      bottom: _collapsed
                          ? const Radius.circular(10)
                          : Radius.zero,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.smart_toy_rounded,
                        size: 16,
                        color: theme.info,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Diagnosis',
                        style: theme.uiLabel.copyWith(
                          color: theme.info,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Pulsing dot while diagnosis is streaming
                      _StreamingIndicator(theme: theme),
                      const Spacer(),
                      // Collapse / expand
                      Tooltip(
                        message: _collapsed ? 'Expand' : 'Collapse',
                        child: Icon(
                          _collapsed
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          size: 16,
                          color: theme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dismiss
                      Tooltip(
                        message: 'Dismiss',
                        child: GestureDetector(
                          onTap: _dismiss,
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: theme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Body (collapsible)
            SizeTransition(
              sizeFactor: _heightFactor,
              alignment: Alignment.topCenter,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: SelectableText(
                    diagnosis,
                    style: theme.monoSmall.copyWith(
                      color: theme.textPrimary,
                      height: 1.55,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pulsing dot shown while the AI is still streaming a response.
class _StreamingIndicator extends ConsumerStatefulWidget {
  final AppTheme theme;
  const _StreamingIndicator({required this.theme});

  @override
  ConsumerState<_StreamingIndicator> createState() =>
      _StreamingIndicatorState();
}

class _StreamingIndicatorState extends ConsumerState<_StreamingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The dot is only visible while the AI is still generating.
    // We check if terminal has the "analysing" marker by watching
    // executionState + aiLoaded together.
    final isRunning =
        ref.watch(executionStateProvider) != ExecutionState.idle;

    if (!isRunning) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              widget.theme.info.withValues(alpha: 0.4 + 0.6 * _pulse.value),
        ),
      ),
    );
  }
}
