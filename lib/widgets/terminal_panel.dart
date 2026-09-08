import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ide_providers.dart';
import '../services/ai_service.dart';
import '../services/execution_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ide_toast.dart';

import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/styles/github.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

/// Bottom output panel with three tabs:
///   0 - Terminal  : stdout / stderr / system lines from code execution.
///   1 - AI Analysis : streamed AI explanation of the last compiler error.
///   2 - Converted Code : Side-by-side view for cross-language conversion.
///
/// The active tab is driven by [bottomTabProvider] so other parts of the app
/// (e.g. [AiService]) can programmatically switch to the AI Analysis tab
/// when a new diagnosis is available.
class TerminalPanel extends ConsumerStatefulWidget {
  const TerminalPanel({super.key});

  @override
  ConsumerState<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends ConsumerState<TerminalPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final ScrollController _terminalScrollController = ScrollController();
  final ScrollController _diagScrollController = ScrollController();

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final GlobalKey _inputKey = GlobalKey();

  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _terminalScrollController.addListener(_onTerminalScroll);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _terminalScrollController.removeListener(_onTerminalScroll);
    _terminalScrollController.dispose();
    _diagScrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // Keep the provider in sync when the user taps a tab manually.
    if (_tabController.indexIsChanging) {
      ref.read(bottomTabProvider.notifier).state = _tabController.index;
    }
  }

  void _onTerminalScroll() {
    if (_terminalScrollController.hasClients) {
      final atBottom = _terminalScrollController.offset >=
          _terminalScrollController.position.maxScrollExtent - 40;
      if (_autoScroll != atBottom) setState(() => _autoScroll = atBottom);
    }
  }

  void _scrollTerminalToBottom() {
    if (_terminalScrollController.hasClients && _autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_terminalScrollController.hasClients) {
          _terminalScrollController.animateTo(
            _terminalScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _scrollDiagToBottom() {
    if (_diagScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_diagScrollController.hasClients) {
          _diagScrollController.animateTo(
            _diagScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.fromType(ref.watch(themeProvider));
    final lines = ref.watch(terminalProvider);
    final diagnosis = ref.watch(aiDiagnosisProvider);
    final isAnalyzing = ref.watch(isAiAnalyzingProvider);
    final activeTab = ref.watch(bottomTabProvider);
    final isRunning = ref.watch(executionStateProvider) != ExecutionState.idle;

    // Sync TabController to provider (e.g. when ai_service switches to tab 1).
    if (_tabController.index != activeTab && !_tabController.indexIsChanging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabController.index != activeTab) {
          _tabController.animateTo(activeTab);
        }
      });
    }

    // Auto-scroll terminal when new lines arrive.
    _scrollTerminalToBottom();

    // Auto-scroll diagnosis tab when AI is streaming.
    if (diagnosis != null) _scrollDiagToBottom();

    // Focus input when running.
    if (isRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && activeTab == 0) _inputFocusNode.requestFocus();
        });
      });
    }

    // Filter out AI lines from the terminal tab -- they live in the AI tab.
    final terminalLines = lines
        .where((l) => l.type != TerminalLineType.ai)
        .toList();

    final hasDiagnosis = diagnosis != null && diagnosis.isNotEmpty;

    return Container(
      margin: const EdgeInsets.all(12).copyWith(top: 0),
      decoration: theme.neumorphicInner(radius: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Tab bar header ──
          Container(
            height: 38,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: theme.panelBorder.withValues(alpha: 0.5), width: 1),
              ),
            ),
            child: Row(
              children: [
                _StyledTabBar(
                  controller: _tabController,
                  theme: theme,
                  hasDiagnosis: hasDiagnosis,
                  isAnalyzing: isAnalyzing,
                  isConverting: ref.watch(isConvertingProvider),
                ),
                const Spacer(),

                // Controls on the right
                if (activeTab == 0 && !_autoScroll) ...[
                  // Auto-scroll button (terminal tab only, when scrolled up)
                  _IconTextButton(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Auto-scroll',
                    color: theme.accent,
                    onTap: () {
                      setState(() => _autoScroll = true);
                      _scrollTerminalToBottom();
                    },
                  ),
                  const SizedBox(width: 8),
                ],

                // Clear button (identical icon, size, and position for all tabs)
                Tooltip(
                  message: activeTab == 0 ? 'Clear terminal' : (activeTab == 1 ? 'Clear analysis' : 'Clear converted code'),
                  child: GestureDetector(
                    onTap: () {
                      if (activeTab == 0) {
                        ref.read(terminalProvider.notifier).clear();
                      } else if (activeTab == 1) {
                        ref.read(aiDiagnosisProvider.notifier).state = null;
                      } else if (activeTab == 2) {
                        ref.read(convertedCodeProvider.notifier).state = null;
                        ref.read(conversionLanguageProvider.notifier).state = null;
                      }
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 15,
                          color: theme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Tab content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // ── Tab 0: Terminal ──
                _TerminalContent(
                  lines: terminalLines,
                  theme: theme,
                  scrollController: _terminalScrollController,
                  inputController: _inputController,
                  inputFocusNode: _inputFocusNode,
                  inputKey: _inputKey,
                  ref: ref,
                ),

                // ── Tab 1: AI Analysis ──
                _DiagnosticContent(
                  diagnosis: diagnosis,
                  isAnalyzing: isAnalyzing,
                  theme: theme,
                  scrollController: _diagScrollController,
                  onStop: () => ref.read(aiServiceProvider).stopAnalysis(),
                ),

                // ── Tab 2: Converted Code ──
                _ConverterContent(
                  theme: theme,
                  onStop: () => ref.read(aiServiceProvider).stopConversion(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Styled Tab Bar ───────────────────────────────────────────────────────────

class _StyledTabBar extends StatelessWidget {
  final TabController controller;
  final AppTheme theme;
  final bool hasDiagnosis;
  final bool isAnalyzing;
  final bool isConverting;

  const _StyledTabBar({
    required this.controller,
    required this.theme,
    required this.hasDiagnosis,
    required this.isAnalyzing,
    required this.isConverting,
  });

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerColor: Colors.transparent,
      indicatorColor: theme.accent,
      indicatorWeight: 2,
      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
      labelStyle: theme.uiLabel.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      unselectedLabelStyle: theme.uiLabel.copyWith(
        fontSize: 11,
        letterSpacing: 0.5,
      ),
      labelColor: theme.accent,
      unselectedLabelColor: theme.textMuted,
      tabs: [
        const Tab(
          height: 38,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.terminal_rounded, size: 13),
              SizedBox(width: 6),
              Text('Terminal'),
            ],
          ),
        ),
        Tab(
          height: 38,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy_outlined, size: 13),
              const SizedBox(width: 6),
              const Text('AI Analysis'),
              if (isAnalyzing) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.info),
                  ),
                ),
              ] else if (hasDiagnosis) ...[
                const SizedBox(width: 5),
                // Small notification dot when diagnosis is present
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.info,
                  ),
                ),
              ],
            ],
          ),
        ),
        Tab(
          height: 38,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_horiz_rounded, size: 13),
              const SizedBox(width: 6),
              const Text('Converted Code'),
              if (isConverting) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.info),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Terminal Tab Content ─────────────────────────────────────────────────────

class _TerminalContent extends StatelessWidget {
  final List<TerminalLine> lines;
  final AppTheme theme;
  final ScrollController scrollController;
  final TextEditingController inputController;
  final FocusNode inputFocusNode;
  final GlobalKey inputKey;
  final WidgetRef ref;

  const _TerminalContent({
    required this.lines,
    required this.theme,
    required this.scrollController,
    required this.inputController,
    required this.inputFocusNode,
    required this.inputKey,
    required this.ref,
  });

  bool get _isRunning =>
      ref.read(executionStateProvider) == ExecutionState.running;

  int _itemCount() {
    if (!_isRunning) return lines.length;
    if (lines.isEmpty || !lines.last.partial) return lines.length + 1;
    return lines.length;
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = ref.watch(executionStateProvider) == ExecutionState.running;

    if (lines.isEmpty && !isRunning) {
      return Center(
        child: Text(
          'Run your code to see output here.',
          style: theme.monoSmall.copyWith(color: theme.textMuted),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _itemCount(),
      itemBuilder: (context, index) {
        // Standalone input field (last item when running)
        if (index == lines.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _inputField(inline: false),
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
                    style: theme.monoSmall.copyWith(
                        color: _colorForType(line.type)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _inputField(inline: true),
                  ),
                ),
              ],
            ),
          );
        }

        // Standard line
        return Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: SelectableText(
            line.text,
            style: theme.monoSmall.copyWith(color: _colorForType(line.type)),
          ),
        );
      },
    );
  }

  Widget _inputField({required bool inline}) {
    return Row(
      key: inputKey,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!inline) ...[
          Text('>', style: theme.monoSmall.copyWith(color: theme.accent)),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                final lines = ref.read(terminalProvider);
                if (lines.isNotEmpty &&
                    lines.last.text.toLowerCase().contains('press any key')) {
                  ref.read(executionServiceProvider).sendInput('');
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: inputController,
              focusNode: inputFocusNode,
              autofocus: true,
              style: theme.monoSmall.copyWith(color: theme.textPrimary),
              cursorColor: theme.accent,
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
                  inputController.clear();
                }
                inputFocusNode.requestFocus();
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
        return theme.textPrimary;
      case TerminalLineType.stderr:
        return theme.error;
      case TerminalLineType.ai:
        return theme.info;
      case TerminalLineType.system:
        return theme.textMuted;
    }
  }
}

// ─── AI Analysis Tab Content ────────────────────────────────────────────────

class _DiagnosticContent extends StatelessWidget {
  final String? diagnosis;
  final bool isAnalyzing;
  final AppTheme theme;
  final ScrollController scrollController;
  final VoidCallback onStop;

  const _DiagnosticContent({
    required this.diagnosis,
    required this.isAnalyzing,
    required this.theme,
    required this.scrollController,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (diagnosis == null || diagnosis!.isEmpty) {
      if (isAnalyzing) {
        content = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.info),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'AI Analyzing...',
                style: theme.monoSmall.copyWith(
                  color: theme.info,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Analyzing error details with $aiModelName...',
                style: theme.uiLabel.copyWith(
                  color: theme.textMuted.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      } else {
        content = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy_outlined,
                  size: 36, color: theme.textMuted.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(
                'No analysis yet.',
                style: theme.monoSmall.copyWith(
                  color: theme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Run code that produces an error and the AI will analyze it here.',
                style: theme.uiLabel.copyWith(
                  color: theme.textMuted.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      }
    } else {
      final formatted = formatAiDiagnosis(diagnosis!);

      content = Container(
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF111927)
              : const Color(0xFFF5F8FF),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(16, 16, 16, isAnalyzing ? 64 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI model name header
              Row(
                children: [
                  Text(
                    'Local LLM Model: $aiModelName',
                    style: theme.monoSmall.copyWith(
                      color: theme.info,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: theme.info.withValues(alpha: 0.2), height: 1),
              const SizedBox(height: 14),
              _buildRichDiagnosis(formatted, theme),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: content),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          right: 16,
          bottom: isAnalyzing ? 16 : -50,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isAnalyzing ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !isAnalyzing,
              child: _FloatingStopButton(
                theme: theme,
                onStop: onStop,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRichDiagnosis(String text, AppTheme theme) {
    final fixHeaderRegex =
        RegExp(r'(^|\n)(Suggested\s+Fix:?)(\s*\n|$)', caseSensitive: false);
    final match = fixHeaderRegex.firstMatch(text);

    if (match == null) {
      return SelectableText(
        text,
        style: theme.monoSmall.copyWith(
          color: theme.textPrimary,
          height: 1.65,
          fontSize: 13,
        ),
      );
    }

    final before = text.substring(0, match.start);
    final codeAndAfter = text.substring(match.end);

    final spans = <InlineSpan>[];

    // 1. Explanation text before the fix
    if (before.trim().isNotEmpty) {
      spans.add(
        TextSpan(
          text: '${before.trimRight()}\n\n',
          style: theme.monoSmall.copyWith(
            color: theme.textPrimary,
            height: 1.65,
            fontSize: 13,
          ),
        ),
      );
    }

    // 2. "Suggested Fix" Header
    spans.add(
      TextSpan(
        text: 'Suggested Fix\n',
        style: theme.uiLabel.copyWith(
          color: theme.info,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          height: 2.0,
        ),
      ),
    );

    // 3. Code lines with line numbers
    final lineRegex = RegExp(r'^(\s*\d+\s*\|\s*)(.*)$');
    final lines = codeAndAfter.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLast = i == lines.length - 1;
      final lineMatch = lineRegex.firstMatch(line);

      if (lineMatch != null) {
        // Dimmed line number gutter (e.g. " 1 | ")
        spans.add(
          TextSpan(
            text: lineMatch.group(1),
            style: theme.monoSmall.copyWith(
              color: theme.editorLineNumber,
              fontSize: 13,
              height: 1.65,
            ),
          ),
        );
        // Code content
        spans.add(
          TextSpan(
            text: isLast ? lineMatch.group(2) : '${lineMatch.group(2)}\n',
            style: theme.monoSmall.copyWith(
              color: theme.textPrimary,
              fontSize: 13,
              height: 1.65,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: isLast ? line : '$line\n',
            style: theme.monoSmall.copyWith(
              color: theme.textPrimary,
              fontSize: 13,
              height: 1.65,
            ),
          ),
        );
      }
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }
}

// ─── Small helper ─────────────────────────────────────────────────────────────

class _IconTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _IconTextButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Floating Stop Button (AI Analysis Tab) ───────────────────────────────────

class _FloatingStopButton extends StatefulWidget {
  final AppTheme theme;
  final VoidCallback onStop;
  final String tooltip;

  const _FloatingStopButton({
    required this.theme,
    required this.onStop,
    this.tooltip = 'Stop/terminate AI analysis',
  });

  @override
  State<_FloatingStopButton> createState() => _FloatingStopButtonState();
}

class _FloatingStopButtonState extends State<_FloatingStopButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final errorColor = widget.theme.error;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onStop,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: widget.theme.neumorphicOuter(radius: 8),
            child: Icon(
              Icons.stop_rounded,
              size: 16,
              color: _hovered ? errorColor : errorColor.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Converted Code Tab Content ───────────────────────────────────────────────

class _ConverterContent extends ConsumerWidget {
  final AppTheme theme;
  final VoidCallback? onStop;
  const _ConverterContent({required this.theme, this.onStop});

  CodeHighlightTheme? _getHighlightTheme(ProgrammingLanguage lang, AppTheme theme) {
    final modeMap = {
      ProgrammingLanguage.c: langC,
      ProgrammingLanguage.cpp: langCpp,
      ProgrammingLanguage.csharp: langCsharp,
      ProgrammingLanguage.java: langJava,
      ProgrammingLanguage.python: langPython,
    };
    final mode = modeMap[lang];
    if (mode == null) return null;
    return CodeHighlightTheme(
      languages: {lang.extension: CodeHighlightThemeMode(mode: mode)},
      theme: theme.brightness == Brightness.dark ? atomOneDarkTheme : githubTheme,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceCode = ref.watch(originalCodeProvider) ?? '';
    final convertedCode = ref.watch(convertedCodeProvider) ?? '';
    final selectedLang = ref.watch(selectedLanguageProvider);
    final targetLangStr = ref.watch(conversionLanguageProvider) ?? '';

    // Find the ProgrammingLanguage enum for the target language to get highlighting
    final targetLang = ProgrammingLanguage.values.firstWhere(
      (l) => l.displayName == targetLangStr,
      orElse: () => selectedLang,
    );

    final isConverting = ref.watch(isConvertingProvider);

    final Widget content;

    if (isConverting) {
      content = Container(
        color: Colors.transparent,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.info),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'AI Converting...',
                style: theme.monoSmall.copyWith(
                  color: theme.info,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Converting code with $aiModelName...',
                style: theme.uiLabel.copyWith(
                  color: theme.textMuted.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (convertedCode.isEmpty) {
      content = Container(
        color: Colors.transparent,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_horiz_rounded, size: 36, color: theme.textMuted.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(
                'No conversion yet.',
                style: theme.monoSmall.copyWith(
                  color: theme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select a target language and convert to see the result here.',
                style: theme.uiLabel.copyWith(
                  color: theme.textMuted.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      content = Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Original Code
            Expanded(
              child: Container(
                decoration: theme.neumorphicInner(radius: 12),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                      child: Text('${selectedLang.displayName} (Original)', style: theme.uiLabel.copyWith(color: theme.textMuted, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: CodeEditor(
                        controller: CodeLineEditingController.fromText(sourceCode),
                        readOnly: true,
                        style: CodeEditorStyle(
                          fontSize: 13,
                          fontFamily: 'JetBrains Mono',
                          codeTheme: _getHighlightTheme(selectedLang, theme),
                          backgroundColor: Colors.transparent,
                          textColor: theme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Converted Code
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: theme.neumorphicInner(radius: 12),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                          child: Text('$targetLangStr (Converted)', style: theme.uiLabel.copyWith(color: theme.info, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: CodeEditor(
                            controller: CodeLineEditingController.fromText(convertedCode),
                            readOnly: true,
                            style: CodeEditorStyle(
                              fontSize: 13,
                              fontFamily: 'JetBrains Mono',
                              codeTheme: _getHighlightTheme(targetLang, theme),
                              backgroundColor: Colors.transparent,
                              textColor: theme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Copy Button
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Tooltip(
                      message: 'Copy to clipboard',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: convertedCode));
                            showIdeToast(context, 'Code copied to clipboard', theme, isError: false, icon: Icons.check_circle_outline_rounded);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: theme.neumorphicOuter(radius: 8),
                            child: Icon(Icons.copy_rounded, size: 16, color: theme.info),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: content),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          right: 16,
          bottom: isConverting ? 16 : -50,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isConverting ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !isConverting,
              child: _FloatingStopButton(
                theme: theme,
                onStop: onStop ?? () => ref.read(aiServiceProvider).stopConversion(),
                tooltip: 'Stop/terminate code conversion',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
