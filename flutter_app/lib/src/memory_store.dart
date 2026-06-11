import 'dart:io';

import 'package:path_provider/path_provider.dart';

class MemoryStore {
  MemoryStore({this.maxLines = 240, this.maxCharacters = 48000});

  final int maxLines;
  final int maxCharacters;

  Future<String> read() async {
    final file = await _file();
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  Future<List<String>> readLines() async {
    final content = await read();
    if (content.trim().isEmpty) return const <String>[];
    return content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Future<void> append(String text) async {
    final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return;
    final lines = <String>[...await readLines(), '- $cleaned'];
    await _writeTrimmed(lines);
  }

  Future<void> _writeTrimmed(List<String> lines) async {
    var next = lines.length > maxLines
        ? lines.sublist(lines.length - maxLines)
        : lines;
    while (next.join('\n').length > maxCharacters && next.length > 1) {
      next = next.sublist(1);
    }
    final file = await _file();
    await file.create(recursive: true);
    await file.writeAsString('${next.join('\n')}\n');
  }

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/studyos_memory.md');
  }
}
