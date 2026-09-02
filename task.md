Act as an expert Flutter and Desktop application developer. Your task is to write the complete codebase for a "Multi-Language Local Compiler IDE" built for Windows.

This IDE allows users to write code in C, C++, C#, Java, and Python, compile/run it locally using native host compilers, stream the output to a terminal UI, and use an embedded, offline LLM to explain compiler errors.

### The Tech Stack

- Framework: Flutter (targeting Windows Desktop)
- State Management: flutter_riverpod
- Code Editor UI: re_editor (for native syntax highlighting and code folding)
- File System: path_provider
- Local AI Engine: lib_llama_cpp (FFI bindings for offline inference)

### Core Features & Architecture Requirements

1. UI Layout (Main Window):
   - Left Panel: A simple placeholder file tree/explorer.
   - Top Toolbar: A dropdown to select the programming language (C, C++, C#, Java, Python), a "Run Code" button, and a "Kill Process" button.
   - Main Center: The `re_editor` code editor.
   - Bottom Panel: A read-only terminal window that displays text streams in real-time.

2. Execution Engine (No Docker, Native dart:io):
   - When the user clicks "Run", write the editor's text to a temporary directory.
   - Use `dart:io`'s `Process.start()` to execute the corresponding local compiler toolchain (e.g., `g++` for C++, `python` for Python, `javac/java` for Java).
   - Stream the `stdout` and `stderr` directly to the Bottom Panel terminal using a `StreamBuilder`.
   - Maintain a reference to the active `Process` so the user can terminate infinite loops using the "Kill Process" button.

3. Offline AI Assistant:
   - Use `lib_llama_cpp` to load a local `.gguf` model (assume the model is located in the app's support directory).
   - If the Execution Engine captures text from `stderr` (e.g., a compiler error), automatically trigger the AI service.
   - Send the code and the error to the LLM with the prompt: "Explain this compiler error and how to fix it."
   - Print the AI's explanation into the Bottom Panel terminal in a distinct color (e.g., yellow or cyan) to differentiate it from standard process output.

### Code Generation Instructions

Please generate the complete, production-ready codebase separated into logical files. I need:

1. `pubspec.yaml` with the correct dependencies.
2. `main.dart` (App initialization and Riverpod ProviderScope).
3. `execution_service.dart` (The logic for temp file creation, Process.start, and streaming stdout/stderr).
4. `ai_service.dart` (The LlamaOpenAIClient setup and prompt execution).
5. `home_screen.dart` (The UI layout tying the editor, toolbar, and terminal stream together).

Write the code cleanly, with comments explaining how the streams and the FFI AI integration work.
