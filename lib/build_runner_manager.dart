import 'dart:async';
import 'dart:io' as io;

import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:build_runner_hook/constants.dart';
import 'package:build_runner_hook/process_context.dart';
import 'package:build_runner_hook/utils.dart';

final class BuildRunnerManager {
  BuildRunnerManager(TempDirectory temp)
    : _temp = temp,
      _lock = TempFile.fromPath(temp.asDirectory.path, "./brh.lock"),
      _log = TempFile.fromPath(temp.asDirectory.path, "./brh.log"),
      _cleanup = TempFile.fromPath(
        temp.asDirectory.path,
        "./cleanup.dart",
      ) {
    if (!_temp.asDirectory.existsSync()) {
      _temp.asDirectory.createSync();
    }
  }

  final TempDirectory _temp;
  final TempFile _lock;
  final TempFile _log;
  final TempFile _cleanup;

  io.IOSink? _lockSink;
  io.IOSink? _logSink;

  final Map<String, ProcessContext> _pathToContextMap = {};

  bool get isInitialized => _lockSink != null && _logSink != null;

  Future<void> init() async {
    if (isInitialized) return;

    try {
      await Future.wait([
        _initializeLog(),
        _initializeLock(),
        _initializeCleanup(),
      ]);
    } catch (e) {
      _logMessage(e.toString());
    }
  }

  Future<void> _initializeLock() async {
    final lockExists = await _lock.exists;

    if (lockExists) await _processLock();

    final file = await _lock.create();
    _lockSink = file.openWrite(mode: .writeOnly);
  }

  Future<void> _initializeLog() async {
    final exists = await _log.exists;
    if (exists) {
      await _log.delete();
    }

    final log = await _log.create();

    _logSink = log.openWrite(mode: .writeOnly);
  }

  Future<void> _initializeCleanup() async {
    final exists = await _cleanup.exists;
    if (exists) return;

    final file = await _cleanup.create();
    await file.writeAsString(cleanupScript);
  }

  void _logMessage(String message) {
    final timestamp = DateTime.now().toIso8601String();

    _logSink?.writeln("TIMESTAMP $timestamp\t$message");
  }

  Future<void> _runCleanup() async {
    await io.Process.start(
      "./cleanup.exe",
      // "dart",
      [
        // "run",
        // "cleanup.dart",
      ],
      mode: .detached,
      workingDirectory: _cleanup.file.parent.path,
    );
  }

  Future<void> _processLock() async {
    final lines = await _lock.file.readAsLines();
    for (final line in lines) {
      final pid = int.tryParse(line.split("\t").last);
      if (pid == null) continue;

      final killed = io.Process.killPid(pid);
      _logMessage("Stopped build_runner process $pid: $killed");
    }

    await _lock.delete();
  }

  void registerContext(ContextRoot ctx) {
    final path = ctx.root.path;

    if (_pathToContextMap.containsKey(path)) {
      _logMessage("$path already processed");
      return;
    }

    final processContext = ProcessContext(
      ctx,
      temp: _temp,
      log: _logMessage,
      onStarted: _onProcessStarted,
    );

    _pathToContextMap[path] = processContext;
    _logMessage("$path saved!");
    unawaited(processContext.start());
  }

  void _writeProcessLock(ProcessContext context, int pid) {
    _lockSink?.writeln("${context.rootPath}\t$pid");
    _logMessage("${context.rootPath} build_runner started with pid $pid");
  }

  void _onProcessStarted(ProcessContext context, int pid) {
    _writeProcessLock(context, pid);
  }

  Future<void> dispose() async {
    await Future.wait([
      _runCleanup(),
      if (_logSink != null) _logSink!.close(),
      if (_lockSink != null) _lockSink!.close(),
    ]);

    _pathToContextMap.clear();
  }
}
