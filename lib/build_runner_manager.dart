import 'dart:io' as io;

import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:build_runner_hook/utils.dart';

final class BuildRunnerManager {
  BuildRunnerManager(TempDirectory temp)
    : _temp = temp,
      _lock = TempFile.fromPath(temp.asDirectory.path, "./brh.lock"),
      _log = TempFile.fromPath(temp.asDirectory.path, "./brh.log") {
    if (!_temp.asDirectory.existsSync()) {
      _temp.asDirectory.createSync();
    }
  }

  final TempDirectory _temp;
  final TempFile _lock;
  final TempFile _log;

  io.IOSink? _lockSink;
  io.IOSink? _logSink;

  final Map<String, ContextRoot> _pathToContextMap = {};

  bool get isInitialized => _lock.existsSync;

  Future<void> init() async {
    if (isInitialized) return;

    try {
      await Future.wait([
        _initializeLock(),
        _initializeLog(),
      ]);
    } catch (e) {
      _logMessage(e.toString());
    }
  }

  Future<void> _initializeLock() async {
    final lockExists = await _lock.exists;

    if (lockExists) {
      _processLock();
    } else {
      final file = await _lock.create();
      _lockSink = file.openWrite(mode: .writeOnly);
    }
  }

  Future<void> _initializeLog() async {
    final exists = await _log.exists;
    if (exists) {
      await _log.delete();
    }

    final log = await _log.create();

    _logSink = log.openWrite(mode: .writeOnly);
  }

  void _logMessage(String message) {
    final timestamp = DateTime.now().toIso8601String();

    _logSink?.writeln("TIMESTAMP $timestamp\t$message");
    _logSink?.flush();
  }

  Future<void> _processLock() async {}

  void registerContext(ContextRoot ctx) {
    final path = ctx.root.path;

    if (_pathToContextMap.containsKey(path)) {
      _logMessage("$path already processed");
      return;
    }

    _pathToContextMap[path] = ctx;
    _logMessage("$path saved!");
  }

  Future<void> dispose() async {
    await Future.wait([
      _lock.delete(),
      if (_logSink != null) _logSink!.close(),
      if (_lockSink != null) _lockSink!.close(),
    ]);

    _pathToContextMap.clear();
  }
}
