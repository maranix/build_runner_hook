import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';

final _defaultPath = "${Directory.systemTemp.path}/build_runner_hook.log";

final class BuildRunnerManager {
  BuildRunnerManager({String? logFilePath})
    : _logFile = File(logFilePath ?? _defaultPath) {
    _sink = _logFile.openWrite(mode: .writeOnly);
  }

  final File _logFile;
  late final IOSink _sink;
  Process? _process;

  final _stdGroup = StreamGroup<List<int>>();
  StreamSubscription<String>? _stdGroupSubscription;

  bool _running = false;
  bool get running => _running;

  void start(String rootDir, {List<String> args = const []}) async {
    if (_running) return;

    _running = true;
    _log("Starting up Build Runner in $rootDir");

    try {
      _process = await Process.start("dart", [
        "run",
        "build_runner",
        "watch",
        ...args,
      ], workingDirectory: rootDir);

      _log("Attching stdout & stderr to Log File");

      _stdGroup
        ..add(_process!.stdout)
        ..add(_process!.stderr);

      _stdGroupSubscription = _stdGroup.stream
          .transform(Utf8Decoder())
          .listen(_log);
      _log("Build Runner is running!");
    } catch (e) {
      _log("Error running Build Runner: $e");
      _running = false;
    }
  }

  void stop() {
    _stdGroupSubscription?.cancel();
    _stdGroup.close();
    _process?.kill();
    _sink.close();
  }

  void _log(String message) {
    final timestamp = DateTime.now();
    _sink.writeln("Timestamp $timestamp\t$message");
  }
}
