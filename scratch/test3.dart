import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swaju_ide/providers/ide_providers.dart';

void main() async {
  final notifier = TerminalNotifier();
  
  notifier.addChunk('Hello', TerminalLineType.stdout);
  notifier.addChunk('World\n', TerminalLineType.stdout);
  
  await Future.delayed(Duration(milliseconds: 100));
  for (var line in notifier.state) {
    print('LINE: ${line.text} (partial: ${line.partial})');
  }
}
