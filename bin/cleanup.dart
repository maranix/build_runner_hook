import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final tempUri = Directory.systemTemp.uri.resolve("./build_runner_hook/");
  final log = File(
    tempUri.resolve("./cleanup.log").toFilePath(),
  );

  final logWriter = log.openWrite(mode: .writeOnly);

  if (args.isNotEmpty) {
    logWriter.writeln("${args[0]} - Processing lock file");
  } else {
    logWriter.writeln("Processing lock file");
  }

  final lockFile = File(tempUri.resolve("./brh.lock").toFilePath());
  final exists = await lockFile.exists();

  if (!exists) {
    logWriter.writeln("Lock file does not exist, Bailing!!");
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

            sink.add(int.parse(line.split("\t").last));
          },
        ),
      )
      .toList();

  for (final pid in pidList) {
    final success = Process.killPid(pid);
    if (!success) {
      logWriter.writeln("Unable to kill $pid");
    }
  }

  logWriter.writeln("Done!");
  await logWriter.close();

  exit(0);
}
