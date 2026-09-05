import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/styles/github.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

import '../providers/ide_providers.dart';
import '../services/ai_service.dart';
import '../services/execution_service.dart';
import '../theme/app_theme.dart';
import '../widgets/terminal_panel.dart';
import '../widgets/toolbar.dart';
import '../widgets/vertical_split_view.dart';

/// Main IDE screen — 4 panel layout.
///
/// ┌──────────────────────────────────────────────────┐
/// │  Toolbar                                         │
/// ├──────────┬───────────────────────────────────────┤
/// │ FileTree │  Code Editor (re_editor)              │
/// │          ├───────────────────────────────────────┤
/// │          │  Terminal Panel                        │
/// └──────────┴───────────────────────────────────────┘
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late CodeLineEditingController _editorController;

  /// Default sample code per language.
  static const _defaultCode = <ProgrammingLanguage, String>{
    ProgrammingLanguage.python: '''# Welcome to Swaju IDE!
# Select a language and click Run.

def greet(name):
    return f"Hello, {name}! Welcome to Swaju IDE."

print(greet("World"))
''',
    ProgrammingLanguage.c: '''// Welcome to Swaju IDE!
#include <stdio.h>

int main() {
    printf("Hello, World! Welcome to Swaju IDE.\\n");
    return 0;
}
''',
    ProgrammingLanguage.cpp: '''// Welcome to Swaju IDE!
#include <iostream>
#include <string>

int main() {
    std::string name = "World";
    std::cout << "Hello, " << name << "! Welcome to Swaju IDE." << std::endl;
    return 0;
}
''',
    ProgrammingLanguage.csharp: '''// Welcome to Swaju IDE!
using System;

class Program {
    static void Main(string[] args) {
        Console.WriteLine("Hello, World! Welcome to Swaju IDE.");
    }
}
''',
    ProgrammingLanguage.java: '''// Welcome to Swaju IDE!
public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, World! Welcome to Swaju IDE.");
    }
}
''',
  };

  @override
  void initState() {
    super.initState();
    _editorController = CodeLineEditingController.fromText(
      _defaultCode[ProgrammingLanguage.python]!,
    );

    // Initialise the AI service on startup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiServiceProvider).initialize();
    });
  }

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  /// Called when the user changes the selected language.
  void _onLanguageChanged(ProgrammingLanguage? prev, ProgrammingLanguage next) {
    if (prev != next) {
      _editorController.text = _defaultCode[next] ?? '';
    }
  }

  /// Run the code currently in the editor.
  Future<void> _runCode() async {
    if (ref.read(executionStateProvider) != ExecutionState.idle) return;

    final language = ref.read(selectedLanguageProvider);
    final code = _editorController.text;
    final executionService = ref.read(executionServiceProvider);

    // Clear previous output.
    ref.read(terminalProvider.notifier).clear();

    try {
      // Execute and capture stderr.
      final stderr = await executionService.execute(code, language);

      // If there were errors, trigger the AI assistant.
      if (stderr.trim().isNotEmpty) {
        final aiService = ref.read(aiServiceProvider);
        await aiService.explainError(code, stderr);
      }
    } catch (e, st) {
      ref.read(terminalProvider.notifier).addLine(
        '✗ Unexpected error: $e',
        TerminalLineType.stderr,
      );
      debugPrint('_runCode error: $e\n$st');
    }
  }

  /// Kill the active process.
  void _killProcess() {
    ref.read(executionServiceProvider).killProcess();
  }

  /// Returns the re_highlight language mode for the selected language.
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
      languages: {
        lang.extension: CodeHighlightThemeMode(mode: mode),
      },
      theme: theme.brightness == Brightness.dark ? atomOneDarkTheme : githubTheme,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.fromType(ref.watch(themeProvider));
    final selectedLang = ref.watch(selectedLanguageProvider);
    final isRunning = ref.watch(executionStateProvider) != ExecutionState.idle;

    // Listen for language changes to swap default code.
    ref.listen<ProgrammingLanguage>(selectedLanguageProvider, _onLanguageChanged);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): () {
          if (!isRunning) _runCode();
        },
        const SingleActivator(LogicalKeyboardKey.f6): () {
          if (isRunning) _killProcess();
        },
      },
      child: FocusScope(
        autofocus: true,
        child: Scaffold(
          backgroundColor: theme.background,
          body: Column(
            children: [
              // ── Top toolbar ──
              Toolbar(onRun: _runCode, onKill: _killProcess),

              // ── Main content area ──
              Expanded(
                child: VerticalSplitView(
                  top: Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    decoration: theme.neumorphicInner(radius: 12),
                    clipBehavior: Clip.antiAlias,
                    child: CodeEditor(
                      controller: _editorController,
                      style: CodeEditorStyle(
                        fontSize: 14,
                        fontFamily: 'JetBrains Mono',
                        codeTheme: _getHighlightTheme(selectedLang, theme),
                        backgroundColor: theme.editorBackground,
                        textColor: theme.textPrimary,
                        cursorColor: theme.accent,
                        selectionColor: theme.accent.withValues(alpha: 0.25),
                        cursorLineColor: theme.editorLineHighlight,
                      ),
                      indicatorBuilder: (
                        context,
                        editingController,
                        chunkController,
                        notifier,
                      ) {
                        return Row(
                          children: [
                            DefaultCodeLineNumber(
                              controller: editingController,
                              notifier: notifier,
                              textStyle: theme.monoSmall.copyWith(
                                color: theme.editorLineNumber,
                              ),
                            ),
                            DefaultCodeChunkIndicator(
                              width: 20,
                              controller: chunkController,
                              notifier: notifier,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  bottom: const TerminalPanel(),
                ),
              ),

              // ── Status bar ──
              _StatusBar(language: selectedLang),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Status bar ──────────────────────────────────────────────────────────────
class _StatusBar extends ConsumerWidget {
  final ProgrammingLanguage language;
  const _StatusBar({required this.language});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.fromType(ref.watch(themeProvider));
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.15),
        border: Border(
          top: BorderSide(color: theme.panelBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            language.displayName,
            style: theme.uiLabel.copyWith(
              color: theme.textSecondary,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          Text(
            'UTF-8',
            style: theme.uiLabel.copyWith(
              color: theme.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Swaju IDE v1.0.0',
            style: theme.uiLabel.copyWith(
              color: theme.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

