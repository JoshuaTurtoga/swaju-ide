import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swaju_ide/providers/ide_providers.dart';
import 'package:swaju_ide/services/execution_service.dart';
import 'dart:io';

void main() async {
  final container = ProviderContainer();
  final execService = container.read(executionServiceProvider);
  final terminal = container.read(terminalProvider.notifier);
  
  // Listen to terminal output and print it
  container.listen(terminalProvider, (prev, next) {
    if (next.isNotEmpty) {
      final last = next.last;
      print('UI Line: ${last.text} (type: ${last.type}, partial: ${last.partial})');
    }
  });

  const code = '''
#include <stdio.h>
int main() {
    printf("Hello\\n");
    return 0;
}
''';

  print('Executing C code...');
  await execService.execute(code, ProgrammingLanguage.c);
  print('Done.');
  
  // print all lines at the end
  print('\n--- ALL UI LINES ---');
  for (final line in container.read(terminalProvider)) {
    print('${line.type.name}: ${line.text}');
  }
}
