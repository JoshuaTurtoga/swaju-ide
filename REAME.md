# ./ACE - Local AI Compiler & Code Runner

**./ACE** is a lightweight, bare-metal multi-language code runner and diagnostic environment built with Flutter Desktop and powered by an embedded, completely offline local LLM.

Because `./ACE` bundles its AI engine directly into the installer, **no internet connection or model downloads are required to use the smart features.** However, since code is executed natively via Dart subprocesses directly on your Windows host for optimal speed, you must ensure your system has the proper language toolchains installed.

---

## 1. System Requirements

- **Operating System:** Windows 10 (64-bit) or Windows 11
- **Memory (RAM):** 8 GB minimum (16 GB recommended)
- **Processor:** x64 or Arm64 multi-core CPU (Intel Core i3/i5/i7/i9 8th Gen+ or AMD Ryzen)
- **Graphics (Optional):** Vulkan-compatible dedicated or integrated GPU for accelerated AI inference.

---

## 2. Pre-Installation Dependencies

Because `./ACE` is built with Flutter Desktop, it renders its UI natively and does not rely on web wrappers like WebView2. The system footprint is incredibly light.

### Essential Runtimes

- **Microsoft Visual C++ Redistributable (x64):**
  - Required by both the Flutter Windows native runner and the bundled `llama.cpp` inference engine.
  - Download and install `vc_redist.x64.exe` from Microsoft (usually pre-installed on modern Windows PCs).
- **Updated GPU Drivers:**
  - Ensure your graphics drivers (NVIDIA, AMD, or Intel) are up to date to allow Vulkan hardware acceleration for the local LLM.

---

## 3. Post-Installation Setup: Language Toolchains

`./ACE` delegates compilation and execution to the compilers installed on your Windows machine. You only need to install the toolchains for the languages you intend to use.

> **CRITICAL:** Every installed toolchain must be added to your Windows **System PATH** environment variable so the Flutter application can locate and run the binaries via `dart:io`.

### C & C++ (MinGW-w64 / GCC)

1. Download a standalone MinGW-w64 build (e.g., via **WinLibs** or **MSYS2**).
2. Extract the archive (e.g., to `C:\mingw64`).
3. Add the `bin` folder path (e.g., `C:\mingw64\bin`) to your Windows **System PATH**.

### Python (3.10+)

1. Download the Windows installer from [python.org](https://www.python.org).
2. During setup, **check the box that says "Add python.exe to PATH"** before clicking Install.

### Java (JDK 17 or higher)

1. Download an OpenJDK distribution (such as Eclipse Temurin or Oracle JDK).
2. Run the installer and ensure the option to **set `JAVA_HOME` and update the PATH** is enabled.

### C# (.NET SDK)

1. Download and install the latest **.NET SDK** (v8.0 or LTS) from Microsoft.
2. The official installer automatically configures all environment variables.

---

## 4. Verification

After installing your required compilers, verify that `./ACE` can communicate with them.

Open **PowerShell** or **Command Prompt** and run the following checks:

```powershell
# Verify C/C++
gcc --version
g++ --version

# Verify Python
python --version

# Verify Java
javac --version
java --version

# Verify C#
dotnet --version
```
