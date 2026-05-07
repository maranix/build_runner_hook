const cleanupScript = '''
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final lockFile = File.fromUri(Directory.systemTemp.uri.resolve("./build_runner_hook/brh.lock"));
  final exists = await lockFile.exists();

  if (!exists) {
    exit(1);
  }

  final pidList = await lockFile
      .openRead()
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .transform(
        StreamTransformer<String, int>.fromHandlers(
          handleData: (line, sink) {
            if (line.isEmpty) return;

            final [path, pid] = line.split("\t");
            sink.add(int.parse(pid));
          },
        ),
      )
      .toList();

  for (final pid in pidList) {
    Process.killPid(pid);
  }

  exit(0);
}''';
