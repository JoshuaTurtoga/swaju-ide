import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lib_llama_cpp/lib_llama_cpp.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/ide_providers.dart';

/// Offline AI service powered by llama.cpp via [lib_llama_cpp].
///
/// This service uses [LlamaOpenAIClient] to run a local GGUF model entirely
/// on-device.  When the execution engine detects stderr output (compiler
/// errors), it calls [explainError] which constructs a prompt and streams
/// the LLM response back into the terminal panel in cyan.
///
/// Design notes:
/// • The model is expected to be at: `<appSupportDir>/models/*.gguf`
/// • If no model file is found, the service logs a warning and returns
///   without crashing — all other IDE features work normally.
/// • Inference runs in a background isolate managed by lib_llama_cpp,
///   so the Flutter UI thread is never blocked.
class AiService {
  final Ref ref;

  LlamaOpenAIClient? _client;
  String? _modelPath;
  bool _initialized = false;

  AiService(this.ref);

  /// Initialise the LLM client by scanning for a .gguf model file.
  ///
  /// Call this once at app startup.  Subsequent calls are no-ops.
  Future<bool> initialize() async {
    if (_initialized) return _client != null;
    _initialized = true;

    try {
      final appDir = await getApplicationSupportDirectory();
      final modelsDir = Directory('${appDir.path}/models');

      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
        ref.read(terminalProvider.notifier).addLine(
          '⚠ AI: No models directory found. Created ${modelsDir.path}',
          TerminalLineType.system,
        );
        ref.read(terminalProvider.notifier).addLine(
          '  Place a .gguf model file there to enable AI error explanations.',
          TerminalLineType.system,
        );
        return false;
      }

      // Find the first .gguf file in the models directory.
      final ggufFiles = modelsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.gguf'))
          .toList();

      if (ggufFiles.isEmpty) {
        ref.read(terminalProvider.notifier).addLine(
          '⚠ AI: No .gguf model file found in ${modelsDir.path}',
          TerminalLineType.system,
        );
        ref.read(terminalProvider.notifier).addLine(
          '  Download a GGUF model and place it there to enable AI.',
          TerminalLineType.system,
        );
        return false;
      }

      _modelPath = ggufFiles.first.path;

      // Create the in-process LlamaOpenAIClient.
      // The model is loaded lazily on first inference request.
      _client = LlamaOpenAIClient(
        models: {
          'local': LlamaModelConfig(
            modelPath: _modelPath!,
            // 2048 context window is enough for error + code snippets
          ),
        },
      );

      ref.read(aiLoadedProvider.notifier).state = true;
      ref.read(terminalProvider.notifier).addLine(
        '✓ AI: Loaded model ${ggufFiles.first.uri.pathSegments.last}',
        TerminalLineType.system,
      );
      return true;
    } catch (e) {
      ref.read(terminalProvider.notifier).addLine(
        '⚠ AI: Failed to initialize — $e',
        TerminalLineType.system,
      );
      return false;
    }
  }

  /// Send the code and compiler error to the LLM and stream the explanation
  /// into the terminal panel.
  ///
  /// If the AI is not available, this is a silent no-op.
  Future<void> explainError(String code, String stderrText) async {
    if (_client == null) return;

    final terminal = ref.read(terminalProvider.notifier);
    terminal.addLine('', TerminalLineType.ai);
    terminal.addLine(
      '🤖 AI is analysing the error…',
      TerminalLineType.ai,
    );

    try {
      // Build the prompt — keep it concise so small models can handle it.
      final prompt = '''
You are a helpful programming tutor. A student got the following compiler/runtime error.
Explain what the error means and how to fix it. Be concise.

--- ERROR ---
$stderrText

--- CODE ---
$code
''';

      // Stream tokens so the user sees the response appear in real-time.
      await for (final event in _client!.responses.stream(
        model: 'local',
        input: prompt,
      )) {
        if (event case LlamaResponseOutputTextDelta(:final delta)) {
          // The delta may contain newlines; split and add each as a
          // separate terminal line so the panel renders correctly.
          final parts = delta.split('\n');
          for (int i = 0; i < parts.length; i++) {
            if (i == 0) {
              // First part: append to current line logic — we add as new
              // line for simplicity since the terminal is line-based.
              if (parts[i].isNotEmpty) {
                terminal.addLine(parts[i], TerminalLineType.ai);
              }
            } else {
              terminal.addLine(parts[i], TerminalLineType.ai);
            }
          }
        }
      }

      terminal.addLine('', TerminalLineType.ai);
    } catch (e) {
      terminal.addLine(
        '⚠ AI error: $e',
        TerminalLineType.system,
      );
    }
  }
}

/// Riverpod provider for the AI service (singleton).
final aiServiceProvider = Provider<AiService>((ref) => AiService(ref));
