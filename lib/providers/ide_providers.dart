import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../theme/app_theme.dart';

// ─── Theme Provider & Transition Event ─────────────────────────────────────────
final themeProvider = StateProvider<AppThemeType>((ref) => AppThemeType.neumorphismWhite);
final rootBoundaryKeyProvider = Provider<GlobalKey>((ref) => GlobalKey());

class ThemeTransitionEvent {
  final Offset origin;
  final Color fromColor;
  final Color toColor;
  final int eventId;
  final ui.Image? image;

  const ThemeTransitionEvent({
    required this.origin,
    required this.fromColor,
    required this.toColor,
    required this.eventId,
    this.image,
  });
}

final themeTransitionEventProvider = StateProvider<ThemeTransitionEvent?>((ref) => null);

// ─── Terminal line model ──────────────────────────────────────────────────────
enum TerminalLineType { stdout, stderr, ai, system }

class TerminalLine {
  final String text;
  final TerminalLineType type;

  /// True when this line has not yet received a trailing newline.
  /// The next chunk from the same stream will extend/replace this line.
  final bool partial;

  TerminalLine({
    required this.text,
    required this.type,
    this.partial = false,
  });
}

// ─── Execution state ─────────────────────────────────────────────────────────
enum ExecutionState { idle, compiling, running }

// ─── Supported languages ─────────────────────────────────────────────────────
enum ProgrammingLanguage {
  c('C', 'c'),
  cpp('C++', 'cpp'),
  csharp('C#', 'cs'),
  java('Java', 'java'),
  python('Python', 'py');

  final String displayName;
  final String extension;
  const ProgrammingLanguage(this.displayName, this.extension);
}

// ─── Providers ───────────────────────────────────────────────────────────────
final selectedLanguageProvider = StateProvider<ProgrammingLanguage>(
  (ref) => ProgrammingLanguage.python,
);

final executionStateProvider = StateProvider<ExecutionState>(
  (ref) => ExecutionState.idle,
);

final activeProcessProvider = StateProvider<Process?>((ref) => null);

final aiLoadedProvider = StateProvider<bool>((ref) => false);

// ─── Terminal notifier ────────────────────────────────────────────────────────
/// Manages terminal output lines.
///
/// Supports **partial lines** — text arriving without a trailing `\n` (e.g. C
/// `printf` prompts).  Each call to [addChunk] merges new text with any
/// pending partial line for that stream type, so prompts appear instantly.
class TerminalNotifier extends StateNotifier<List<TerminalLine>> {
  TerminalNotifier() : super([]);

  final List<TerminalLine> _buffer = [];
  Timer? _flushTimer;

  /// Pending (no trailing \n) text keyed by stream type.
  final Map<TerminalLineType, String> _pending = {};

  // ── Public API ──────────────────────────────────────────────────────────

  /// Add a complete line (caller guarantees the text is a full line).
  void addLine(String text, TerminalLineType type) {
    // If there's a pending partial for this type, close it first.
    _closePending(type);
    _buffer.add(TerminalLine(text: text, type: type, partial: false));
    _scheduleFlush();
  }

  /// Add a raw chunk of decoded text that may or may not contain newlines.
  ///
  /// This is the key method for real-time output: it handles prompts like
  /// `printf("Enter: ")` which have no trailing newline.
  void addChunk(String chunk, TerminalLineType type) {
    // Strip Windows \r so they don't appear as garbage characters.
    final cleaned = chunk.replaceAll('\r', '');
    final combined = (_pending[type] ?? '') + cleaned;
    final parts = combined.split('\n');
    final trailingNewline = combined.endsWith('\n');

    if (parts.length == 1) {
      // No newline at all — entire text is a partial line.
      _pending[type] = combined;
      _buffer.add(TerminalLine(text: combined, type: type, partial: true));
    } else {
      // First part closes any previous partial.
      _buffer.add(TerminalLine(text: parts[0], type: type, partial: false));
      _pending.remove(type);

      // Middle parts are complete lines.
      for (int i = 1; i < parts.length - 1; i++) {
        _buffer.add(TerminalLine(text: parts[i], type: type, partial: false));
      }

      // Last part — new partial if no trailing newline.
      if (!trailingNewline && parts.last.isNotEmpty) {
        _pending[type] = parts.last;
        _buffer.add(TerminalLine(text: parts.last, type: type, partial: true));
      }
    }

    _scheduleFlush();
  }

  void clear() {
    _pending.clear();
    _buffer.clear();
    state = [];
  }

  // ── Private ─────────────────────────────────────────────────────────────

  void _closePending(TerminalLineType type) {
    _pending.remove(type);
  }

  void _scheduleFlush() {
    if (_flushTimer?.isActive ?? false) return;
    _flushTimer = Timer(const Duration(milliseconds: 30), _flush);
  }

  void _flush() {
    if (_buffer.isEmpty) return;

    final next = List<TerminalLine>.from(state);

    for (final item in _buffer) {
      if (next.isNotEmpty && next.last.partial && next.last.type == item.type) {
        // Replace the previous partial line (same stream type) with the
        // updated/extended version.
        next[next.length - 1] = item;
      } else {
        next.add(item);
      }
    }

    // Cap history at 1000 lines.
    state = next.length > 1000 ? next.sublist(next.length - 1000) : next;
    _buffer.clear();
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }
}

final terminalProvider =
    StateNotifierProvider<TerminalNotifier, List<TerminalLine>>(
  (ref) => TerminalNotifier(),
);
