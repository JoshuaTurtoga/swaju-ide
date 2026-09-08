import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../providers/ide_providers.dart';

const String _ollamaUrl = 'http://127.0.0.1:11434';
const String aiModelName = 'qwen2.5-coder:7b';

/// Offline AI service powered by a local Ollama server.
///
/// Implements the three features defined in FEATURES.md:
/// Features:
///   1. Error Diagnosis (Compiler/Runtime) -- [explainError]
///   2. Cross-Language Converter  -- [convertCode]
class AiService {
  final Ref ref;
  bool _initialized = false;

  AiService(this.ref);

  // --- Lifecycle --------------------------------------------------------------

  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      final response = await http
          .get(Uri.parse('$_ollamaUrl/api/tags'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        _initialized = true;
        ref.read(aiLoadedProvider.notifier).state = true;
        ref.read(terminalProvider.notifier).addLine(
          'AI: Connected to local Ollama server.',
          TerminalLineType.system,
        );
        return true;
      } else {
        ref.read(terminalProvider.notifier).addLine(
          'AI: Ollama responded with ${response.statusCode}.',
          TerminalLineType.system,
        );
        return false;
      }
    } catch (_) {
      ref.read(terminalProvider.notifier).addLine(
        'AI: Could not reach Ollama. Is it running? (ollama serve)',
        TerminalLineType.system,
      );
      return false;
    }
  }

  // --- Feature 1: Cryptic Error Translator -----------------------------------
  //
  // Trigger: Dart Process.run / Process.start returns non-zero exit or stderr.
  // Prompt architecture from FEATURES.md section 1.

  http.Client? _activeAnalysisClient;
  bool _isAnalysisCancelled = false;

  /// Stops and terminates any active AI error analysis.
  void stopAnalysis() {
    _isAnalysisCancelled = true;
    _activeAnalysisClient?.close();
    _activeAnalysisClient = null;
    ref.read(isAiAnalyzingProvider.notifier).state = false;
    final currentDiag = ref.read(aiDiagnosisProvider);
    if (currentDiag == null || currentDiag.isEmpty) {
      ref.read(aiDiagnosisProvider.notifier).state =
          'AI analysis stopped by user.';
    } else if (!currentDiag.contains('AI analysis stopped by user')) {
      ref.read(aiDiagnosisProvider.notifier).state =
          '$currentDiag\n\n[AI analysis stopped by user]';
    }
  }

  Future<void> explainError(String code, String stderrText) async {
    if (!_initialized) return;

    // Abort any prior in-flight analysis and reset cancellation flag.
    _activeAnalysisClient?.close();
    _activeAnalysisClient = null;
    _isAnalysisCancelled = false;

    ref.read(isAiAnalyzingProvider.notifier).state = true;
    ref.read(terminalProvider.notifier).addLine('AI is analyzing please wait...', TerminalLineType.system);
    // Clear any previous diagnosis and switch to the AI Analysis tab.
    ref.read(aiDiagnosisProvider.notifier).state = null;
    ref.read(bottomTabProvider.notifier).state = 1;

    // System prompt instructing the model to provide line-numbered fixes under "Suggested Fix".
    const systemPrompt =
        'You are an expert compiler diagnostic tool.\n'
        'Analyze the following raw compiler/interpreter error.\n\n'
        '1. Identify the programming language.\n'
        '2. Explain the error in one or two simple, plain-English sentences.\n'
        '3. Provide a brief code snippet showing how to fix it.\n'
        '   CRITICAL FORMATTING INSTRUCTIONS FOR SUGGESTED FIX:\n'
        '   - Do NOT use markdown code fences (do NOT use ``` or ```<language> on top, and do NOT use ``` at the end).\n'
        '   - Put the header "Suggested Fix" right before the code snippet.\n'
        '   - Prefix every line of the code snippet with its line number (e.g. 1 | <code line>).\n'
        '   - Do not use conversational filler.';

    final fullPrompt = '$systemPrompt\n\nRAW ERROR:\n$stderrText\n\nCODE:\n$code';

    try {
      final client = http.Client();
      _activeAnalysisClient = client;

      final request =
          http.Request('POST', Uri.parse('$_ollamaUrl/api/generate'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': aiModelName,
        'prompt': fullPrompt,
        'stream': true,
        'options': {'temperature': 0.1},
      });

      final response = await client.send(request);

      final diagBuffer = StringBuffer();

      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (_isAnalysisCancelled) break;
        if (chunk.isEmpty) continue;
        final data = jsonDecode(chunk) as Map<String, dynamic>;
        final text = data['response'] as String? ?? '';
        if (text.isNotEmpty) {
          diagBuffer.write(text);
          // Update the AI Analysis tab with the formatted streamed text in real time.
          ref.read(aiDiagnosisProvider.notifier).state =
              formatAiDiagnosis(diagBuffer.toString());
        }
      }

      if (_isAnalysisCancelled) {
        ref.read(terminalProvider.notifier).addLine(
          'AI Analysis stopped by user.',
          TerminalLineType.system,
        );
      } else {
        ref.read(terminalProvider.notifier).addLine(
          'AI Analysis complete. See the AI Analysis tab.',
          TerminalLineType.system,
        );
      }
    } catch (e) {
      if (_isAnalysisCancelled) {
        ref.read(terminalProvider.notifier).addLine(
          'AI Analysis stopped by user.',
          TerminalLineType.system,
        );
      } else {
        ref.read(terminalProvider.notifier).addLine('AI error: $e', TerminalLineType.system);
      }
    } finally {
      _activeAnalysisClient?.close();
      _activeAnalysisClient = null;
      ref.read(isAiAnalyzingProvider.notifier).state = false;
    }
  }


  // --- Feature 2: Cross-Language Converter -----------------------------------
  //
  // Trigger: "Convert Code" ElevatedButton -> showDialog -> DropdownMenu.
  // Prompt architecture from FEATURES.md section 3.

  http.Client? _activeConversionClient;
  bool _isConversionCancelled = false;

  /// Stops and terminates any active AI code conversion.
  void stopConversion() {
    _isConversionCancelled = true;
    _activeConversionClient?.close();
    _activeConversionClient = null;
    ref.read(isConvertingProvider.notifier).state = false;
    ref.read(terminalProvider.notifier).addLine(
      'Conversion stopped by user.',
      TerminalLineType.system,
    );
  }

  Future<String?> convertCode(
    String sourceCode,
    String sourceLanguage,
    String targetLanguage,
  ) async {
    if (!_initialized) return null;

    _activeConversionClient?.close();
    _activeConversionClient = null;
    _isConversionCancelled = false;

    // System prompt exactly as defined in FEATURES.md section 3.
    final prompt =
        'You are an expert multi-language developer.\n'
        'Translate the following $sourceLanguage code exactly into $targetLanguage.\n'
        'Maintain the exact same logic, variable naming conventions, and architecture.\n'
        'Output ONLY the raw $targetLanguage code. '
        'Do not include markdown formatting, backticks, explanations, or conversational text.\n\n'
        'SOURCE CODE:\n$sourceCode';

    try {
      final client = http.Client();
      _activeConversionClient = client;

      final response = await client.post(
        Uri.parse('$_ollamaUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': aiModelName,
          'prompt': prompt,
          'stream': false,
          'options': {'temperature': 0.05},
        }),
      );

      if (_isConversionCancelled) return null;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        var result = (data['response'] as String? ?? '').trim();
        
        // Strip markdown code fences if the LLM still includes them
        result = result.replaceAll(RegExp(r'^```[a-zA-Z0-9_+-]*\n?', multiLine: true), '');
        result = result.replaceAll(RegExp(r'```$'), '');
        result = result.trim();
        
        return result.isEmpty ? null : result;
      }
    } catch (e) {
      if (_isConversionCancelled) return null;
      ref.read(terminalProvider.notifier).addLine(
        'Conversion error: $e',
        TerminalLineType.system,
      );
    } finally {
      _activeConversionClient = null;
    }
    return null;
  }

  // --- Feature 3: Chatbot ---------------------------------------------------

  http.Client? _activeChatClient;
  bool _isChatCancelled = false;

  void stopChat() {
    _isChatCancelled = true;
    _activeChatClient?.close();
    _activeChatClient = null;
  }

  void clearChat() {
    stopChat();
    ref.read(chatMessagesProvider.notifier).state = [];
  }

  Future<void> streamChat(String prompt) async {
    if (!_initialized) return;

    // Add user message
    final currentMsgs = ref.read(chatMessagesProvider);
    ref.read(chatMessagesProvider.notifier).state = [
      ...currentMsgs,
      ChatMessage(text: prompt, role: ChatRole.user)
    ];

    // Add empty AI message (streaming)
    ref.read(chatMessagesProvider.notifier).state = [
      ...ref.read(chatMessagesProvider),
      const ChatMessage(text: '', role: ChatRole.ai, isStreaming: true)
    ];

    _activeChatClient?.close();
    _activeChatClient = null;
    _isChatCancelled = false;

    try {
      final client = http.Client();
      _activeChatClient = client;

      // Construct messages history for /api/chat
      final allMsgs = ref.read(chatMessagesProvider);
      final messages = allMsgs.where((m) => !m.isStreaming && m.text.isNotEmpty).map((m) {
        return {
          'role': m.role == ChatRole.user ? 'user' : 'assistant',
          'content': m.text,
        };
      }).toList();

      final request = http.Request('POST', Uri.parse('$_ollamaUrl/api/chat'));
      request.headers['Content-Type'] = 'application/json';
      
      const systemPrompt = "You are ./ACE AI Assistant, a helpful programming chatbot. "
          "You must only answer programming-related questions and provide code in languages supported by this IDE: C, C++, C#, Java, and Python. "
          "If the user asks a non-programming question, politely refuse. "
          "When generating code, always use markdown code fences (e.g. ```python) so the UI can format it properly.";

      messages.insert(0, {'role': 'system', 'content': systemPrompt});

      request.body = jsonEncode({
        'model': aiModelName,
        'messages': messages,
        'stream': true,
      });

      final response = await client.send(request);

      final aiBuffer = StringBuffer();

      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (_isChatCancelled) break;
        if (chunk.isEmpty) continue;
        final data = jsonDecode(chunk) as Map<String, dynamic>;
        final messageChunk = data['message'] as Map<String, dynamic>?;
        final text = messageChunk?['content'] as String? ?? '';
        if (text.isNotEmpty) {
          aiBuffer.write(text);
          final msgs = List<ChatMessage>.from(ref.read(chatMessagesProvider));
          msgs[msgs.length - 1] = ChatMessage(text: aiBuffer.toString(), role: ChatRole.ai, isStreaming: true);
          ref.read(chatMessagesProvider.notifier).state = msgs;
        }
      }

      if (!_isChatCancelled) {
        final msgs = List<ChatMessage>.from(ref.read(chatMessagesProvider));
        msgs[msgs.length - 1] = ChatMessage(text: msgs.last.text, role: ChatRole.ai, isStreaming: false);
        ref.read(chatMessagesProvider.notifier).state = msgs;
      }

    } catch (e) {
      if (!_isChatCancelled) {
         final msgs = List<ChatMessage>.from(ref.read(chatMessagesProvider));
         msgs[msgs.length - 1] = ChatMessage(text: msgs.last.text + '\n[Error: $e]', role: ChatRole.ai, isStreaming: false);
         ref.read(chatMessagesProvider.notifier).state = msgs;
      }
    } finally {
      _activeChatClient?.close();
      _activeChatClient = null;
    }
  }
}

final aiServiceProvider = Provider<AiService>((ref) => AiService(ref));

/// Formats the raw AI diagnosis text:
/// 1. Replaces markdown code fences (e.g. ```python) with a "Suggested Fix" header.
/// 2. Removes trailing ``` from the code.
/// 3. Ensures the suggested fix snippet has line numbers format (e.g. "1 | <code line>").
String formatAiDiagnosis(String raw) {
  if (raw.isEmpty) return raw;

  // 1. Check if there is a markdown code fence like ```python, ```dart, ```, etc.
  final fenceRegex = RegExp(r'```([a-zA-Z0-9_+-]*)');
  final match = fenceRegex.firstMatch(raw);

  if (match != null) {
    var beforeFence = raw.substring(0, match.start);
    var afterFence = raw.substring(match.end);

    // If afterFence starts with a newline, strip it so code starts on a fresh line
    if (afterFence.startsWith('\r\n')) {
      afterFence = afterFence.substring(2);
    } else if (afterFence.startsWith('\n')) {
      afterFence = afterFence.substring(1);
    }

    // Check for closing fence ```
    final closingIndex = afterFence.indexOf('```');
    String codeSection;
    String trailingText = '';
    if (closingIndex != -1) {
      codeSection = afterFence.substring(0, closingIndex);
      trailingText = afterFence.substring(closingIndex + 3);
    } else {
      codeSection = afterFence;
    }

    // Clean up any stray ``` in beforeFence or trailingText
    beforeFence = beforeFence.replaceAll('```', '');
    trailingText = trailingText.replaceAll('```', '');

    // Clean up beforeFence: check if it already has "Suggested Fix" header
    var trimmedBefore = beforeFence.trimRight();
    final hasSuggestedFixHeader = RegExp(
      r'suggested\s+fix:?\s*$',
      caseSensitive: false,
    ).hasMatch(trimmedBefore);

    final header = hasSuggestedFixHeader
        ? '\n'
        : (trimmedBefore.isEmpty ? 'Suggested Fix\n' : '\n\nSuggested Fix\n');

    if (hasSuggestedFixHeader) {
      trimmedBefore = trimmedBefore.replaceFirst(
        RegExp(r'suggested\s+fix:?\s*$', caseSensitive: false),
        'Suggested Fix',
      );
    }

    // Number the lines in codeSection
    final numberedCode = _numberCodeLines(codeSection);

    final buffer = StringBuffer();
    buffer.write(trimmedBefore);
    buffer.write(header);
    buffer.write(numberedCode);
    if (trailingText.trim().isNotEmpty) {
      buffer.write('\n\n');
      buffer.write(trailingText.trim());
    }
    return buffer.toString();
  }

  // 2. What if the LLM did not use ``` fences, but wrote "Suggested Fix:"?
  final suggestedFixMatch = RegExp(
    r'(^|\n)(Suggested\s+Fix:?)(\s*\n|$)',
    caseSensitive: false,
  ).firstMatch(raw);

  if (suggestedFixMatch != null) {
    final before = raw.substring(0, suggestedFixMatch.start);
    final after = raw.substring(suggestedFixMatch.end);
    final numberedCode = _numberCodeLines(after);

    final buffer = StringBuffer();
    if (before.trim().isNotEmpty) {
      buffer.write(before.trimRight());
      buffer.write('\n\n');
    }
    buffer.write('Suggested Fix\n');
    buffer.write(numberedCode);
    return buffer.toString();
  }

  return raw;
}

String _numberCodeLines(String code) {
  var lines = code.split('\n');

  // Strip leading blank lines
  while (lines.isNotEmpty && lines.first.trim().isEmpty) {
    lines.removeAt(0);
  }

  // Strip trailing blank lines
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }

  if (lines.isEmpty) return '';

  // Check if lines already have line numbers (e.g. "1 | " or "1: " or "1. ")
  final alreadyNumbered = lines.every((l) =>
      l.trim().isEmpty ||
      RegExp(r'^\s*\d+\s*[|:]').hasMatch(l));

  if (alreadyNumbered) {
    return lines.join('\n');
  }

  final totalLines = lines.length;
  final padWidth = totalLines.toString().length;

  final numbered = <String>[];
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final numStr = (i + 1).toString().padLeft(padWidth);
    numbered.add('$numStr | $line');
  }

  return numbered.join('\n');
}

