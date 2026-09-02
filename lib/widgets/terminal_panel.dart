                    import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ide_providers.dart';
import '../services/execution_service.dart';
import '../theme/app_theme.dart';

/// Read-only terminal panel that displays colour-coded output.
///
/// Each [TerminalLine] is rendered with a colour matching its [TerminalLineType]:
///   • stdout  → light grey
///   • stderr  → red
///   • ai      → cyan
///   • system  → muted / dim
///
/// The panel auto-scrolls to the bottom when new lines arrive unless the user
/// has manually scrolled up (scroll-lock behaviour).
class TerminalPanel extends ConsumerStatefulWidget {
  const TerminalPanel({super.key});

  @override
  ConsumerState<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends ConsumerState<TerminalPanel> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final GlobalKey _inputKey = GlobalKey();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // If user scrolls away from the bottom, disable auto-scroll.
    if (_scrollController.hasClients) {
      final atBottom = _scrollController.offset >=
          _scrollController.position.maxScrollExtent - 40;
      if (_autoScroll != atBottom) {
        setState(() => _autoScroll = atBottom);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && _autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(terminalProvider);

    // Trigger auto-scroll and focus requests whenever lines change.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      if (ref.read(executionStateProvider) == ExecutionState.running) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _inputFocusNode.requestFocus();
        });
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.terminalBackground,
        border: Border(
          top: BorderSide(color: AppTheme.panelBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── Terminal header bar ──
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(
                bottom: BorderSide(color: AppTheme.panelBorder, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal_rounded, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text('OUTPUT', style: AppTheme.uiLabel),
                const Spacer(),
                // Auto-scroll indicator
                if (!_autoScroll)
                  GestureDetector(
                    onTap: () {
                      setState(() => _autoScroll = true);
                      _scrollToBottom();
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 12,
                            color: AppTheme.accent,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Auto-scroll',
                            style: AppTheme.uiLabel.copyWith(
                              color: AppTheme.accent,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // Clear button
                GestureDetector(
                  onTap: () => ref.read(terminalProvider.notifier).clear(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Tooltip(
                      message: 'Clear terminal',
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Terminal content and input ──
          Expanded(
            child: lines.isEmpty && ref.watch(executionStateProvider) != ExecutionState.running
                ? Center(
                    child: Text(
                      'Run your code to see output here.',
                      style: AppTheme.monoSmall.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _calculateItemCount(lines),
                    itemBuilder: (context, index) {
                      final isRunning = ref.watch(executionStateProvider) == ExecutionState.running;

                      // Standalone input field on a new line
                      if (index == lines.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _buildInputField(inline: false),
                        );
                      }

                      final line = lines[index];
                      final isLastLine = index == lines.length - 1;

                      // Inline input field (attached to a partial prompt line)
                      if (isRunning && isLastLine && line.partial) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 1),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: SelectableText(
                                  line.text,
                                  style: AppTheme.monoSmall.copyWith(
                                    color: _colorForType(line.type),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: _buildInputField(inline: true),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Standard complete line
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: SelectableText(
                          line.text,
                          style: AppTheme.monoSmall.copyWith(
                            color: _colorForType(line.type),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  int _calculateItemCount(List<TerminalLine> lines) {
    final isRunning = ref.watch(executionStateProvider) == ExecutionState.running;
    if (!isRunning) return lines.length;
    // If running, we need an extra item for the input field ONLY IF the last line isn't partial.
    // If it is partial, the input field shares the same index as the last line (rendered inline).
    if (lines.isEmpty || !lines.last.partial) return lines.length + 1;
    return lines.length;
  }

  Widget _buildInputField({required bool inline}) {
    return Row(
      key: _inputKey,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!inline) ...[
          Text('>', style: AppTheme.monoSmall.copyWith(color: AppTheme.accent)),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Focus(
            onKeyEvent: (node, event) {
              // If the program is specifically asking to "press any key", simulate raw mode
              // by instantly sending a newline when they press any key.
              if (event is KeyDownEvent) {
                final lines = ref.read(terminalProvider);
                if (lines.isNotEmpty && 
                    lines.last.text.toLowerCase().contains('press any key')) {
                  ref.read(executionServiceProvider).sendInput(''); // sends \n
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              autofocus: true,
              style: AppTheme.monoSmall.copyWith(color: AppTheme.textPrimary),
              cursorColor: AppTheme.accent,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
              onSubmitted: (value) async {
                if (value.isEmpty) {
                  await ref.read(executionServiceProvider).sendInput('');
                } else {
                  await ref.read(executionServiceProvider).sendInput(value);
                  _inputController.clear();
                }
                _inputFocusNode.requestFocus();
              },
            ),
          ),
        ),
      ],
    );
  }

  Color _colorForType(TerminalLineType type) {
    switch (type) {
      case TerminalLineType.stdout:
        return AppTheme.textPrimary;
      case TerminalLineType.stderr:
        return AppTheme.error;
      case TerminalLineType.ai:
        return AppTheme.info;
      case TerminalLineType.system:
        return AppTheme.textMuted;
    }
  }
}
