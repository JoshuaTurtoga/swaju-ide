# ./ACE - AI Feature Specifications (Flutter Desktop)

This document outlines the implementation details, trigger conditions, and prompt structures for the local LLM features powered by `llama.cpp` and Qwen2.5-Coder.

## Architecture & Distribution Strategy: Offline & Portable LLM

The local Large Language Model (LLM) is integrated directly into the `./ACE` Flutter Desktop application architecture to ensure true portability. By bundling the `llama.cpp` execution engine and the quantized Qwen2.5-Coder model directly as assets in your Windows build (e.g., inside the MSIX package or Inno Setup installer), the application can be seamlessly shared.

Flutter compiles down to a highly optimized, native Windows executable using a C++ runner. Because of this, the end-user gets an incredibly fast "Smart IDE" out of the box without needing to configure API keys, install third-party dependencies (like Python or Docker), or rely on a Wi-Fi connection to download massive models.

---

## 1. Cryptic Error Translator

**Description:** Intercepts raw, difficult-to-read compiler/interpreter errors and translates them into plain English with actionable fix suggestions.

- **Supported Languages:** C, C++, C#, Java, Python.
- **Trigger Condition:** Automatically executes when Dart's `Process.run()` or `Process.start()` (used to execute the compiler) returns a non-zero exit code or data via the `stderr` stream.
- **Execution Flow:**
  1. Code fails to compile/run.
  2. The Dart backend captures the `stderr` output.
  3. An async HTTP call (`package:http`) is made to the local LLM sidecar spawned during application startup.
  4. The response is rendered in a persistent Flutter `Container` or `Card` widget positioned above the terminal view.
- **Prompt Architecture (System):**
  > You are an expert compiler diagnostic tool.
  > Analyze the following raw compiler/interpreter error.
  >
  > 1. Identify the programming language.
  > 2. Explain the error in one or two simple, plain-English sentences.
  > 3. Provide a brief code snippet showing how to fix it.
  >    Do not use conversational filler.
  >
  > RAW ERROR:
  > {stderr_output}

---

## 2. Offline Autocomplete (Ghost Text) using FIM

**Description:** Provides real-time, low-latency code prediction as the user types, displaying suggestions as inline "ghost text" within the editor widget.

- **Supported Languages:** C, C++, C#, Java, Python.
- **Trigger Condition:** Debounced execution (e.g., 300ms) triggered by the `addListener` method on your code editor's `TextEditingController`, provided the AI is not already processing a previous prediction.
- **Execution Flow:**
  1. User types in the Flutter text editor.
  2. Dart extracts the exact cursor position from `TextSelection`.
  3. Code is split into two strings: `prefix` (start of file to cursor) and `suffix` (cursor to end of file).
  4. Local LLM processes the FIM prompt.
  5. The result is drawn on the screen as ghost text (e.g., using a Flutter `Stack` to overlay gray text exactly where the cursor is, or by extending `TextSpan`).
  6. User accepts via keyboard shortcut (e.g., `LogicalKeyboardKey.tab`).
- **Prompt Architecture (Qwen-specific FIM):**
  > <|fim_prefix|>{code_above_cursor}<|fim_suffix|>{code_below_cursor}<|fim_middle|>

---

## 3. Cross-Language Converter

**Description:** Translates a fully working script (or highlighted code block) from its current language into another language supported by the environment.

- **Supported Languages (Source & Target):** C, C++, C#, Java, Python.
- **Trigger Condition:** User taps a "Convert Code" `ElevatedButton` in the UI toolbar, which opens a `showDialog` modal prompting them to select the target language from a `DropdownMenu`.
- **Execution Flow:**
  1. User selects target language and confirms.
  2. Dart grabs the current editor text (or the text within the current `TextSelection.baseOffset` and `extentOffset`) and the target language string.
  3. Async API call is made to the local LLM sidecar.
  4. The editor opens a split-screen view (using a Flutter `Row` with `Expanded` widgets) to display a diff or the translated code side-by-side.
- **Prompt Architecture (System):**
  > You are an expert multi-language developer.
  > Translate the following {source_language} code exactly into {target_language}.
  > Maintain the exact same logic, variable naming conventions, and architecture.
  > Output ONLY the raw {target_language} code. Do not include markdown formatting or explanations.
  >
  > SOURCE CODE:
  > {editor_content}
