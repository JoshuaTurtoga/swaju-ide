//
// Generated file. Do not edit.
// This file is generated from template in file `flutter_tools/lib/src/flutter_plugins.dart`.
//

// @dart = 3.7

import 'dart:io'; // flutter_ignore: dart_io_import.
import 'package:lib_llama_cpp_android/lib_llama_cpp_android.dart' as lib_llama_cpp_android;
import 'package:path_provider_android/path_provider_android.dart' as path_provider_android;
import 'package:lib_llama_cpp_ios/lib_llama_cpp_ios.dart' as lib_llama_cpp_ios;
import 'package:path_provider_foundation/path_provider_foundation.dart' as path_provider_foundation;
import 'package:lib_llama_cpp_linux/lib_llama_cpp_linux.dart' as lib_llama_cpp_linux;
import 'package:path_provider_linux/path_provider_linux.dart' as path_provider_linux;
import 'package:lib_llama_cpp_macos/lib_llama_cpp_macos.dart' as lib_llama_cpp_macos;
import 'package:path_provider_foundation/path_provider_foundation.dart' as path_provider_foundation;
import 'package:lib_llama_cpp_windows/lib_llama_cpp_windows.dart' as lib_llama_cpp_windows;
import 'package:path_provider_windows/path_provider_windows.dart' as path_provider_windows;

@pragma('vm:entry-point')
class _PluginRegistrant {

  @pragma('vm:entry-point')
  static void register() {
    if (Platform.isAndroid) {
      try {
        lib_llama_cpp_android.LibLlamaCppAndroid.registerWith();
      } catch (err) {
        print(
          '`lib_llama_cpp_android` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        path_provider_android.PathProviderAndroid.registerWith();
      } catch (err) {
        print(
          '`path_provider_android` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isIOS) {
      try {
        lib_llama_cpp_ios.LibLlamaCppIos.registerWith();
      } catch (err) {
        print(
          '`lib_llama_cpp_ios` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        path_provider_foundation.PathProviderFoundation.registerWith();
      } catch (err) {
        print(
          '`path_provider_foundation` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isLinux) {
      try {
        lib_llama_cpp_linux.LibLlamaCppLinux.registerWith();
      } catch (err) {
        print(
          '`lib_llama_cpp_linux` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        path_provider_linux.PathProviderLinux.registerWith();
      } catch (err) {
        print(
          '`path_provider_linux` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isMacOS) {
      try {
        lib_llama_cpp_macos.LibLlamaCppMacos.registerWith();
      } catch (err) {
        print(
          '`lib_llama_cpp_macos` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        path_provider_foundation.PathProviderFoundation.registerWith();
      } catch (err) {
        print(
          '`path_provider_foundation` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isWindows) {
      try {
        lib_llama_cpp_windows.LibLlamaCppWindows.registerWith();
      } catch (err) {
        print(
          '`lib_llama_cpp_windows` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        path_provider_windows.PathProviderWindows.registerWith();
      } catch (err) {
        print(
          '`path_provider_windows` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    }
  }
}
