import 'dart:async';

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
import 'package:flutter_svg/flutter_svg.dart';

import '../providers/ide_providers.dart';
import '../services/ai_service.dart';
import '../services/execution_service.dart';
import '../theme/app_theme.dart';
import '../widgets/terminal_panel.dart';
import '../widgets/toolbar.dart';
import '../widgets/vertical_split_view.dart';
import '../widgets/theme_transition_overlay.dart';
import '../widgets/ide_toast.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late CodeLineEditingController _editorController;
  late AnimationController _themeAnimController;
  late Animation<double> _themeAnim;
  ThemeTransitionEvent? _lastThemeEvent;


  static const _defaultCode = <ProgrammingLanguage, String>{
    ProgrammingLanguage.python: 'def greet(name):\n    return f"Hello, {name}! Welcome to ./ACE."\n\nprint(greet("World"))\n',
    ProgrammingLanguage.c: '#include <stdio.h>\n\nint main() {\n    printf("Hello, World!\\n");\n    return 0;\n}\n',
    ProgrammingLanguage.cpp: '#include <iostream>\n\nint main() {\n    std::cout << "Hello, World!" << std::endl;\n    return 0;\n}\n',
    ProgrammingLanguage.csharp: 'using System;\n\nclass Program {\n    static void Main(string[] args) {\n        Console.WriteLine("Hello, World!");\n    }\n}\n',
    ProgrammingLanguage.java: 'public class Main {\n    public static void main(String[] args) {\n        System.out.println("Hello, World!");\n    }\n}\n',
  };

  @override
  void initState() {
    super.initState();
    _editorController = CodeLineEditingController.fromText(
      _defaultCode[ProgrammingLanguage.python]!,
    );
    _themeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _themeAnim = CurvedAnimation(parent: _themeAnimController, curve: Curves.easeInOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiServiceProvider).initialize();
    });
  }

  @override
  void dispose() {
    _editorController.dispose();
    _themeAnimController.dispose();
    super.dispose();
  }


  Future<void> _runCode() async {
    if (ref.read(executionStateProvider) != ExecutionState.idle) return;
    ref.read(aiDiagnosisProvider.notifier).state = null;
    ref.read(convertedCodeProvider.notifier).state = null;
    final language = ref.read(selectedLanguageProvider);
    final code = _editorController.text;
    ref.read(terminalProvider.notifier).clear();
    try {
      final stderr = await ref.read(executionServiceProvider).execute(code, language);
      if (stderr.trim().isNotEmpty) {
        await ref.read(aiServiceProvider).explainError(code, stderr);
      }
    } catch (e, st) {
      ref.read(terminalProvider.notifier).addLine('Unexpected error: $e', TerminalLineType.stderr);
      debugPrint('_runCode error: $e\n$st');
    }
  }

  void _killProcess() => ref.read(executionServiceProvider).killProcess();

  Future<void> _openConvertDialog() async {
    final th = AppTheme.fromType(ref.read(themeProvider));
    final selectedLang = ref.read(selectedLanguageProvider);
    
    // Auto run silently to verify if code is error-free before converting
    await ref.read(executionServiceProvider).execute(_editorController.text, selectedLang, silent: true);

    final hasError = ref.read(hasCompilationErrorProvider);
    if (hasError) {
      if (mounted) showIdeToast(context, 'Please fix code errors before converting', th, isError: true);
      return;
    }

    final available = ProgrammingLanguage.values.where((l) => l != selectedLang).toList();
    ProgrammingLanguage? targetLang = available.first;

    Widget langIcon(ProgrammingLanguage lang) {
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
      );
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDs) {
          return AlertDialog(
            backgroundColor: th.background,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: th.panelBorder)),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: th.neumorphicOuter(radius: 8),
                child: Icon(Icons.swap_horiz_rounded, color: th.info, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Convert Code', style: th.uiText.copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
            ]),
            content: Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: th.neumorphicInner(radius: 12),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Convert from ${selectedLang.displayName} to:', style: th.uiTextSmall.copyWith(color: th.textSecondary)),
                const SizedBox(height: 14),
                DropdownMenu<ProgrammingLanguage>(
                  initialSelection: targetLang,
                  expandedInsets: EdgeInsets.zero,
                  leadingIcon: targetLang != null ? Padding(
                    padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                    child: langIcon(targetLang!),
                  ) : null,
                  textStyle: th.uiText,
                  inputDecorationTheme: InputDecorationTheme(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: th.surface,
                  ),
                  menuStyle: MenuStyle(
                    visualDensity: VisualDensity.standard,
                    backgroundColor: WidgetStatePropertyAll(th.surface),
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: th.panelBorder))),
                  ),
                  dropdownMenuEntries: available.map((l) => DropdownMenuEntry(
                    value: l, 
                    label: l.displayName,
                    leadingIcon: Padding(
                      padding: const EdgeInsets.only(right: 8.0, left: 4.0),
                      child: langIcon(l),
                    ),
                  )).toList(),
                  onSelected: (lang) => setDs(() => targetLang = lang),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: th.uiTextSmall.copyWith(color: th.textMuted))),
              GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: th.neumorphicOuter(radius: 8),
                  child: Text('Convert Now', style: th.uiText.copyWith(color: th.info, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          );
        });
      },
    );

    if (confirmed != true || targetLang == null) return;
    ref.read(terminalProvider.notifier).addLine('Converting ${selectedLang.displayName} to ${targetLang!.displayName}...', TerminalLineType.system);
    ref.read(isConvertingProvider.notifier).state = true;
    ref.read(bottomTabProvider.notifier).state = 2; // Switch terminal to Converted Code tab immediately
    final converted = await ref.read(aiServiceProvider).convertCode(_editorController.text, selectedLang.displayName, targetLang!.displayName);
    if (mounted) ref.read(isConvertingProvider.notifier).state = false;
    if (converted != null && mounted) {
      ref.read(originalCodeProvider.notifier).state = _editorController.text;
      ref.read(convertedCodeProvider.notifier).state = converted;
      ref.read(conversionLanguageProvider.notifier).state = targetLang!.displayName;
      ref.read(terminalProvider.notifier).addLine('Conversion complete.', TerminalLineType.system);
    }
  }

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
  Widget build(BuildContext context) {
    final theme = AppTheme.fromType(ref.watch(themeProvider));
    final selectedLang = ref.watch(selectedLanguageProvider);
    final isRunning = ref.watch(executionStateProvider) != ExecutionState.idle;

    ref.listen<ProgrammingLanguage>(selectedLanguageProvider, (prev, next) {
      if (prev != next) {
        _editorController.text = _defaultCode[next] ?? '';
      }
    });

    ref.listen<ThemeTransitionEvent?>(themeTransitionEventProvider, (prev, next) {
      if (next != null && next.eventId != _lastThemeEvent?.eventId) {
        setState(() => _lastThemeEvent = next);
        _themeAnimController.forward(from: 0.0);
      }
    });

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): () { if (!isRunning) _runCode(); },
        const SingleActivator(LogicalKeyboardKey.f6): () { if (isRunning) _killProcess(); },
      },
      child: FocusScope(
        autofocus: true,
        child: Stack(children: [
          RepaintBoundary(
            key: ref.watch(rootBoundaryKeyProvider),
            child: Scaffold(
              backgroundColor: theme.background,
              body: Column(children: [
                Toolbar(onRun: _runCode, onKill: _killProcess, onConvert: _openConvertDialog),
                Expanded(
                  child: VerticalSplitView(
                    top: Container(
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      decoration: theme.neumorphicInner(radius: 12),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(children: [
                        CodeEditor(
                          controller: _editorController,
                          style: CodeEditorStyle(
                            fontSize: 14,
                            fontFamily: 'JetBrains Mono',
                            codeTheme: _getHighlightTheme(selectedLang, theme),
                            backgroundColor: theme.editorBackground,
                            textColor: theme.textPrimary,
                            cursorColor: theme.accent,
                          ),
                          indicatorBuilder: (context, editingController, chunkController, notifier) {
                            return Row(children: [
                              DefaultCodeLineNumber(
                                controller: editingController,
                                notifier: notifier,
                                textStyle: theme.monoSmall.copyWith(color: theme.editorLineNumber),
                              ),
                              DefaultCodeChunkIndicator(width: 20, controller: chunkController, notifier: notifier),
                            ]);
                          },
                        ),
                      ]),
                    ),
                    bottom: const TerminalPanel(),
                  ),
                ),
                _StatusBar(language: selectedLang),
              ]),
            ),
          ),
          if (_lastThemeEvent != null && _lastThemeEvent!.image != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _themeAnim,
                  builder: (context, _) => ClipPath(
                    clipper: HoleClipper(progress: _themeAnim.value, origin: _lastThemeEvent!.origin),
                    child: RawImage(image: _lastThemeEvent!.image, fit: BoxFit.fill),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}


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
        border: Border(top: BorderSide(color: theme.panelBorder, width: 1)),
      ),
      child: Row(children: [
        Text(language.displayName, style: theme.uiLabel.copyWith(color: theme.textSecondary, fontSize: 11)),
        const Spacer(),
        Text('UTF-8', style: theme.uiLabel.copyWith(color: theme.textMuted, fontSize: 11)),
        const SizedBox(width: 16),
        Text('./ACE v1.0.0', style: theme.uiLabel.copyWith(color: theme.textMuted, fontSize: 11)),
        const SizedBox(width: 16),
        Text('by jswtrtg.dev', style: theme.uiLabel.copyWith(color: theme.textMuted, fontSize: 11)),
      ]),
    );
  }
}
