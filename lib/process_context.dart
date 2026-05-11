import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:path/path.dart' as p;

typedef ProcessLogger = void Function(String message);
typedef ProcessStarted = void Function(ProcessContext context, int pid);

const _watchArgs = ["run", "build_runner", "watch"];
const _watchWorkspaceArgs = ["run", "build_runner", "watch", "--workspace"];
const _workspaceArgs = ["pub", "workspace", "list"];

final class ProcessContext {
  ProcessContext(
    this.contextRoot, {
    required String packageDirectory,
    required ProcessLogger log,
    required ProcessStarted onStarted,
    this.buildFilters = const [],
  }) : _packageDirectory = packageDirectory,
       _log = log,
       _onStarted = onStarted;

  final ContextRoot contextRoot;
  final String _packageDirectory;
  final ProcessLogger _log;
  final ProcessStarted _onStarted;
  final List<String> buildFilters;

  io.Process? _process;
  io.IOSink? _logSink;

  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;

  String get rootPath => contextRoot.root.path;

  int? get pid => _process?.pid;

  bool get isRunning => _process != null;

  Future<void> start() async {
    if (isRunning) {
      _log("$rootPath build_runner already running with pid $pid");
      return;
    }

    final packageName = _readPackageName();
    if (!_hasBuildRunnerDependency()) {
      _log("$packageName does not depend on build_runner; skipping startup");
      return;
    }

    final logFile = await _createLogFile();
    _logSink = logFile.openWrite(mode: .writeOnly);
    _writeLog("Starting build_runner for $packageName in $rootPath");

    final isWorkspace = await _isDartWorkspace();

    try {
      final args = [
        ...switch (isWorkspace) {
          true => _watchWorkspaceArgs,
          false => _watchArgs,
        },
        for (final filter in buildFilters) '--build-filter=$filter',
      ];

      final process = await io.Process.start(
        "dart",
        args,
        workingDirectory: rootPath,
      );

      _process = process;
      _onStarted(this, process.pid);
      _writeLog("Started build_runner with pid ${process.pid}");

      _stdoutSubscription = _lineStream(process.stdout).listen(
        (line) => _writeLog("[stdout] $line"),
        onError: (Object error, StackTrace stackTrace) {
          _writeLog("[stdout:error] $error");
        },
      );
      _stderrSubscription = _lineStream(process.stderr).listen(
        (line) => _writeLog("[stderr] $line"),
        onError: (Object error, StackTrace stackTrace) {
          _writeLog("[stderr:error] $error");
        },
      );

      unawaited(_watchExit(process));
    } catch (error, stackTrace) {
      _writeLog("Failed to start build_runner: $error");
      _writeLog(stackTrace.toString());
    }
  }

  Future<io.File> _createLogFile() async {
    final logFile = io.File(p.join(_packageDirectory, "build_runner.log"));

    if (await logFile.exists()) {
      await logFile.delete();
    }

    return logFile.create(recursive: true);
  }

  Future<void> _watchExit(io.Process process) async {
    final exitCode = await process.exitCode;
    _writeLog("build_runner exited with code $exitCode");

    if (identical(_process, process)) {
      _process = null;
    }
  }

  Future<void> dispose() async {
    await Future.wait([
      if (_stdoutSubscription != null) _stdoutSubscription!.cancel(),
      if (_stderrSubscription != null) _stderrSubscription!.cancel(),
      if (_logSink != null) _logSink!.close(),
    ]);

    _stdoutSubscription = null;
    _stderrSubscription = null;
    _logSink = null;
  }

  String _readPackageName() {
    var start = rootPath.length - 1;

    while (start >= 0) {
      if (rootPath[start] == io.Platform.pathSeparator) {
        break;
      }

      start -= 1;
    }

    return rootPath.substring(start + 1, rootPath.length);
  }

  bool _hasBuildRunnerDependency() {
    for (final pkg in contextRoot.workspace.packages.packages) {
      if (pkg.name == "build_runner") return true;
    }

    return false;
  }

  Stream<String> _lineStream(Stream<List<int>> stream) {
    return stream.transform(utf8.decoder).transform(const LineSplitter());
  }

  void _writeLog(String message) {
    final timestamp = DateTime.now().toIso8601String();

    _logSink?.writeln("TIMESTAMP $timestamp\t$message");
  }

  Future<bool> _isDartWorkspace() async {
    final process = await io.Process.start(
      "dart",
      _workspaceArgs,
      workingDirectory: rootPath,
    );

    final exitCode = await process.exitCode;
    if (exitCode > 0) return false;

    final pkgCount = await process.stdout
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .skip(1)
        .fold(0, (prev, next) {
          if (next.isNotEmpty) return prev + 1;
          return prev;
        });

    return pkgCount > 1;
  }
}
