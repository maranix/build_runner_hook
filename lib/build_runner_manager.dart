import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:async/async.dart';

final _logUri = Directory.systemTemp.uri;
final _pluginLogUri = _logUri.resolve("./brh.log");

final class BuildRunnerManager {
  BuildRunnerManager()
    : _pluginSink = File(
        _pluginLogUri.toFilePath(),
      ).openWrite(mode: .writeOnly);

  final IOSink _pluginSink;

  IOSink? _buildRunnerSink;
  Process? _process;

  final _stdGroup = StreamGroup<List<int>>();
  StreamSubscription<String>? _stdGroupSubscription;

  bool _running = false;
  bool get running => _running;

  void start(String path) async {
    if (_running) return;

    _running = true;

    final pkg = getPkgNameFromPath(path);

    logPlugin("Creating log for $pkg package");

    _buildRunnerSink = File(
      _logUri.resolve("./brh_$pkg.log").toFilePath(),
    ).openWrite(mode: .writeOnly);

    try {
      final isWorkspace = await _isDartWorkspace(path);
      final args = [
        "run",
        "build_runner",
        "watch",
        if (isWorkspace) "--workspace",
      ];

      logPlugin("Starting Build Runner in $path using ${args.skip(1)}");

      _process = await Process.start("dart", args, workingDirectory: path);

      logPlugin("Attching stdout & stderr to Log File");

      _stdGroup
        ..add(_process!.stdout)
        ..add(_process!.stderr);

      _stdGroupSubscription = _stdGroup.stream
          .transform(Utf8Decoder())
          .listen(logBuildRunner);

      logPlugin("Build Runner running in $path");
    } catch (e) {
      logPlugin("Error running Build Runner: $e");
      _running = false;
    }
  }

  Future<void> stop() async {
    logPlugin("Stopping Build Runner");

    await _stdGroupSubscription?.cancel();
    await _stdGroup.close();

    await _buildRunnerSink?.close();
    _process?.kill();

    logPlugin("Build Runner stopped");
    await _pluginSink.close();
  }

  void logPlugin(String message) {
    final timestamp = DateTime.now();
    _pluginSink.writeln("Timestamp $timestamp\t$message");
  }

  void logBuildRunner(String message) {
    final timestamp = DateTime.now();
    _buildRunnerSink?.writeln("Timestamp $timestamp\t$message");
  }

  String getPkgNameFromPath(String path) {
    var start = path.length - 1;

    while (start >= 0) {
      if (path[start] == Platform.pathSeparator) {
        break;
      }

      start--;
    }

    return path.substring(start + 1, path.length);
  }

  bool hasBuildRunner(ContextRoot ctx) {
    for (final pkg in ctx.workspace.packages.packages) {
      if (pkg.name == "build_runner") return true;
    }

    return false;
  }

  Future<bool> _isDartWorkspace(String path) async {
    try {
      final process = await Process.start("dart", [
        "pub",
        "workspace",
        "list",
      ], workingDirectory: path);

      final pkgCount = await process.stdout
          .transform(Utf8Decoder())
          .transform(LineSplitter())
          .skip(1)
          .fold(0, (prev, next) {
            if (next.isEmpty) return prev;

            return prev + 1;
          });

      process.kill();
      return pkgCount > 1;
    } catch (e) {
      logPlugin(
        "Unable to determine whether $path is in a Dart Workspace"
        "\n"
        "${e.toString()}",
      );

      return false;
    }
  }
}
