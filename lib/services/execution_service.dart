import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/ide_providers.dart';

// ─── Language toolchain configuration ────────────────────────────────────────
class _LangConfig {
  final String extension;
  final List<String>? compileCmd;
  final List<String> runCmd;
  final String? className;

  const _LangConfig({
    required this.extension,
    this.compileCmd,
    required this.runCmd,
    this.className,
  });
}

final _langConfigs = <ProgrammingLanguage, _LangConfig>{
  ProgrammingLanguage.c: const _LangConfig(
    extension: 'c',
    compileCmd: ['gcc', '{file}', '-o', '{out}'],
    runCmd: ['{out}'],
  ),
  ProgrammingLanguage.cpp: const _LangConfig(
    extension: 'cpp',
    compileCmd: ['g++', '{file}', '-o', '{out}'],
    runCmd: ['{out}'],
  ),
  ProgrammingLanguage.csharp: const _LangConfig(
    extension: 'cs',
    compileCmd: [
      'dotnet',
      'build',
      '-nologo',
      '-o',
      '{dir}\\out',
      '{dir}\\main.csproj',
    ],
    runCmd: ['{out}'],
  ),
  ProgrammingLanguage.java: _LangConfig(
    extension: 'java',
    compileCmd: const ['javac', '{file}'],
    runCmd: const ['java', '-cp', '{dir}', '{name}'],
    className: 'Main',
  ),
  ProgrammingLanguage.python: const _LangConfig(
    extension: 'py',
    compileCmd: null,
    runCmd: ['python', '{file}'],
  ),
};

// ─── Unbuffering snippet injected into C/C++ before compilation ───────────────
const _cUnbufferSnippet = r'''

// --- SWAJU IDE AUTO-INJECTED ---
#ifdef __cplusplus
#include <cstdio>
extern "C" {
#else
#include <stdio.h>
#endif
void _swaju_unbuf(void) __attribute__((constructor));
void _swaju_unbuf(void) { setvbuf(stdout,0,4,0); }
#ifdef __cplusplus
}
#endif
''';

// ─── Execution service ──────────────────────────────────────────────────────
class ExecutionService {
  final Ref ref;
  ExecutionService(this.ref);

  void _log(String text, TerminalLineType type, {bool chunk = false, bool silent = false}) {
    if (silent) return;
    try {
      final notifier = ref.read(terminalProvider.notifier);
      if (chunk) {
        notifier.addChunk(text, type);
      } else {
        notifier.addLine(text, type);
      }
    } catch (_) {}
  }

  void _logChunk(String text, TerminalLineType type, {bool silent = false}) => _log(text, type, chunk: true, silent: silent);

  String? _javaBinDir;

  /// Automatically locates java/javac in default install paths if missing from PATH,
  /// and guarantees both tools use the exact same JDK version.
  Future<String?> _findJavaTool(String toolName) async {
    // If we've already resolved a JDK bin directory for this session, stick to it
    // to guarantee javac and java versions perfectly match.
    if (_javaBinDir != null) {
      final exe = File('$_javaBinDir\\$toolName.exe');
      if (exe.existsSync()) return exe.path;
    }

    try {
      final res = await Process.run(toolName, ['-version']);
      if (res.exitCode == 0) return toolName;
    } catch (_) {}

    final baseDirs = [
      'C:\\Program Files\\Eclipse Adoptium',
      'C:\\Program Files\\Java',
    ];
    for (final baseDir in baseDirs) {
      final dir = Directory(baseDir);
      if (dir.existsSync()) {
        final jdks = dir.listSync().whereType<Directory>();
        for (final jdk in jdks) {
          final bin = '${jdk.path}\\bin';
          final exe = File('$bin\\$toolName.exe');
          if (exe.existsSync()) {
            _javaBinDir = bin; // Save this exact JDK path for subsequent tool lookups!
            return exe.path;
          }
        }
      }
    }
    return null;
  }

  void _setState(ExecutionState s) {
    try { ref.read(executionStateProvider.notifier).state = s; } catch (_) {}
  }

  void _setProcess(Process? p) {
    try { ref.read(activeProcessProvider.notifier).state = p; } catch (_) {}
  }

  /// Compile and run [code] in the given [language].
  /// Returns accumulated stderr text (empty if none).
  Future<String> execute(String code, ProgrammingLanguage language, {bool silent = false}) async {
    final config = _langConfigs[language]!;
    final stderrBuffer = StringBuffer();

    // Reset error state at start of execution
    try {
      ref.read(hasCompilationErrorProvider.notifier).state = false;
    } catch (_) {}

    // ── 1. Write source file ──────────────────────────────────────
    late Directory workDir;
    late String filePath;
    late String outPath;
    late String currentClassName;

    try {
      final tempDir = await getTemporaryDirectory();
      workDir = Directory('${tempDir.path}\\swaju_ide_run');
      try {
        if (await workDir.exists()) await workDir.delete(recursive: true);
      } catch (_) {
        // Fallback if previous process or antivirus is locking the folder
        workDir = Directory('${tempDir.path}\\swaju_ide_run_${DateTime.now().millisecondsSinceEpoch}');
      }
      await workDir.create(recursive: true);

      currentClassName = config.className ?? 'main';
      if (language == ProgrammingLanguage.java) {
        final match = RegExp(r'public\s+class\s+([A-Za-z0-9_]+)').firstMatch(code);
        if (match != null) {
          currentClassName = match.group(1)!;
        }
      }

      final fileName = language == ProgrammingLanguage.java
          ? '$currentClassName.${config.extension}'
          : 'main.${config.extension}';

      if (language == ProgrammingLanguage.csharp) {
        // Console.ReadKey crashes when stdin is redirected (as it is in our IDE).
        // We transparently patch it to Console.Read() so user code runs smoothly.
        code = code.replaceAll('Console.ReadKey', 'Console.Read');
      }

      final normalizedWorkDir = workDir.path.replaceAll('\\', '/');
      filePath = '$normalizedWorkDir/$fileName';

      outPath = '$normalizedWorkDir/out/main.exe';
      await Directory('$normalizedWorkDir/out').create();
      await File(filePath).writeAsString(code);

      if (language == ProgrammingLanguage.csharp) {
        final csproj = '''<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>''';
        await File('${workDir.path}\\main.csproj').writeAsString(csproj);
      }
    } catch (e) {
      _log('✗ Failed to create temp files: $e', TerminalLineType.stderr, silent: silent);
      return '';
    }

    _log('▶ Running ${language.displayName}…', TerminalLineType.system, silent: silent);

    // ── 2. Compile ────────────────────────────────────────────────
    if (config.compileCmd != null) {
      if (!silent) _setState(ExecutionState.compiling);
      _log('  Compiling…', TerminalLineType.system, silent: silent);

      String sub(String a) => a
          .replaceAll('{file}', filePath)
          .replaceAll('{out}', outPath)
          .replaceAll('{dir}', workDir.path)
          .replaceAll('{name}', currentClassName);

      final args = config.compileCmd!.map(sub).toList();

      if (language == ProgrammingLanguage.java) {
        final javac = await _findJavaTool('javac');
        if (javac != null) args[0] = javac;
      }

      try {
        final proc = await Process.start(args.first, args.sublist(1),
            workingDirectory: workDir.path);
        _setProcess(proc);
        _startPiping(proc, stderrBuffer, silent: silent);
        final code = await proc.exitCode;
        _setProcess(null);

        if (code != 0) {
          _log('✗ Compilation failed (exit $code)', TerminalLineType.system, silent: silent);
          if (!silent) _setState(ExecutionState.idle);
          try {
            ref.read(hasCompilationErrorProvider.notifier).state = true;
          } catch (_) {}
          return stderrBuffer.toString();
        }
        _log('  Compilation succeeded.', TerminalLineType.system, silent: silent);
      } catch (e) {
        _log('✗ Compiler not found: ${args.first}', TerminalLineType.stderr, silent: silent);
        final hint = _compilerInstallHint(language);
        if (hint != null) _log(hint, TerminalLineType.system, silent: silent);
        if (!silent) _setState(ExecutionState.idle);
        try {
          ref.read(hasCompilationErrorProvider.notifier).state = true;
        } catch (_) {}
        return 'Compiler not found: $e';
      }
    }

    // ── 3. Run ────────────────────────────────────────────────────
    if (!silent) _setState(ExecutionState.running);

    String sub(String a) => a
        .replaceAll('{file}', filePath)
        .replaceAll('{out}', outPath)
        .replaceAll('{dir}', workDir.path)
        .replaceAll('{name}', currentClassName);

    final runArgs = config.runCmd.map(sub).toList();

    if (language == ProgrammingLanguage.java) {
      final java = await _findJavaTool('java');
      if (java != null) runArgs[0] = java;
    }

    try {
      final proc = await Process.start(runArgs.first, runArgs.sublist(1),
          workingDirectory: workDir.path);
      _setProcess(proc);

      // Pipe output in background — do NOT await so the event loop stays free
      // and sendInput() can write to stdin while the process is alive.
      _startPiping(proc, stderrBuffer, silent: silent);

      final exitCode = await proc.exitCode;
      _setProcess(null);
      _log('── Process exited with code $exitCode ──', TerminalLineType.system, silent: silent);
      
      if (exitCode != 0 || stderrBuffer.isNotEmpty) {
        try {
          ref.read(hasCompilationErrorProvider.notifier).state = true;
        } catch (_) {}
      }
    } catch (e) {
      _log('✗ Runtime not found: ${runArgs.first}', TerminalLineType.stderr, silent: silent);
      _log('  Make sure the runtime is installed and on your PATH.', TerminalLineType.system, silent: silent);
      try {
        ref.read(hasCompilationErrorProvider.notifier).state = true;
      } catch (_) {}
    }

    if (!silent) _setState(ExecutionState.idle);
    return stderrBuffer.toString();
  }

  /// Kill the active process.
  void killProcess() {
    try {
      final process = ref.read(activeProcessProvider);
      if (process != null) {
        process.kill(ProcessSignal.sigkill);
        _setProcess(null);
        _setState(ExecutionState.idle);
        _log('■ Process killed by user.', TerminalLineType.system);
      }
    } catch (_) {}
  }

  /// Returns a user-friendly install hint for a missing compiler, or null.
  String? _compilerInstallHint(ProgrammingLanguage lang) {
    switch (lang) {
      case ProgrammingLanguage.java:
        return 'Java JDK not found. Install from: https://adoptium.net '
            'and add its bin/ folder to PATH.';
      case ProgrammingLanguage.csharp:
        return 'C# compiler not found. Ensure .NET Framework or .NET SDK is installed.';
      case ProgrammingLanguage.c:
      case ProgrammingLanguage.cpp:
        return 'GCC not found. Install via MSYS2 (https://www.msys2.org).';
      default:
        return 'Make sure the compiler is installed and on your PATH.';
    }
  }

  /// Send a line of input to the running process's stdin.
  Future<void> sendInput(String input) async {
    try {
      final process = ref.read(activeProcessProvider);
      if (process != null) {
        // Simulate the \n a real terminal echoes when the user presses Enter.
        // This closes the current partial stdout prompt line so the next
        // printf output starts on a fresh line instead of appending to it.
        ref.read(terminalProvider.notifier).addChunk('\n', TerminalLineType.stdout);

        process.stdin.writeln(input);
        await process.stdin.flush();
        _log('  ← $input', TerminalLineType.system);
      }
    } catch (e) {
      _log('✗ Could not send input: $e', TerminalLineType.stderr);
    }
  }

  // ── Background stdout/stderr piping ──────────────────────────────
  //
  // We use addChunk (not addLine) so that C printf prompts without a
  // trailing \n appear immediately in the terminal instead of being held
  // by LineSplitter until a newline arrives.
  void _startPiping(Process process, StringBuffer stderrBuffer, {bool silent = false}) {
    process.stdout
        .transform(utf8.decoder)
        .listen(
          (chunk) => _log(chunk, TerminalLineType.stdout, chunk: true, silent: silent),
          onError: (_) {},
          cancelOnError: false,
        );

    process.stderr
        .transform(utf8.decoder)
        .listen(
          (chunk) {
            _logChunk(chunk, TerminalLineType.stderr, silent: silent);
            stderrBuffer.write(chunk.replaceAll('\r', ''));
          },
          onError: (_) {},
          cancelOnError: false,
        );
  }
}

/// Riverpod provider for the execution service.
final executionServiceProvider = Provider<ExecutionService>(
  (ref) => ExecutionService(ref),
);
