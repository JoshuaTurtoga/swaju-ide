import 'dart:io';
import 'dart:convert';

void main() async {
  final proc = await Process.start('.\\test.exe', []);
  proc.stdout.transform(utf8.decoder).listen((data) => print('STDOUT: $data'));
  proc.stderr.transform(utf8.decoder).listen((data) => print('STDERR: $data'));
  await proc.exitCode;
}
