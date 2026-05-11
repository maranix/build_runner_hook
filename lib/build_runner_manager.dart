import 'dart:async';
import 'dart:io' as io;

import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:build_runner_hook/process_context.dart';
import 'package:build_runner_hook/runtime_registry.dart';
import 'package:build_runner_hook/utils.dart';

final class BuildRunnerManager {
  BuildRunnerManager(TempDirectory temp)
    : _temp = temp,
      _log = TempFile.fromPath(temp.asDirectory.path, "./brh.log") {
    _runtime = RuntimeRegistry(temp, log: _logMessage);

    if (!_temp.asDirectory.existsSync()) {
      _temp.asDirectory.createSync();
    }
  }

  final TempDirectory _temp;
  final TempFile _log;
  late final RuntimeRegistry _runtime;

  io.IOSink? _logSink;

  final Map<String, ProcessContext> _pathToContextMap = {};
  final Set<String> _pendingRootPaths = {};

  bool get isInitialized => _logSink != null;

  Future<void> init() async {
    if (isInitialized) return;

    try {
      await _initializeLog();
      await _runtime.cleanupAll();
      await _runtime.startDetachedWatchdog();
    } catch (e) {
      _logMessage(e.toString());
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
  }

  void registerContext(ContextRoot ctx) {
    final path = ctx.root.path;

    if (_pathToContextMap.containsKey(path)) return;
    if (_pendingRootPaths.contains(path)) return;

    _pendingRootPaths.add(path);
    unawaited(_registerContext(ctx));
  }

  Future<void> _registerContext(ContextRoot ctx) async {
    final path = ctx.root.path;

    try {
      await _runtime.registerOwner(path);

      final processContext = ProcessContext(
        ctx,
        temp: _temp,
        log: _logMessage,
        onStarted: _onProcessStarted,
      );

      _pathToContextMap[path] = processContext;
      _logMessage("$path registered!");
      unawaited(processContext.start());
    } catch (e) {
      _logMessage("Failed to register $path: $e");
    } finally {
      _pendingRootPaths.remove(path);
    }
  }

  void _recordBuildRunnerPid(ProcessContext context, int pid) {
    unawaited(_runtime.recordBuildRunnerPid(context.rootPath, pid));
    _logMessage("${context.rootPath} build_runner started with pid $pid");
  }

  void _onProcessStarted(ProcessContext context, int pid) {
    _recordBuildRunnerPid(context, pid);
  }

  Future<void> dispose() async {
    await _runtime.startDetachedCleanup();
    await Future.wait(_pathToContextMap.keys.map(_runtime.removeOwner));
    await Future.wait(
      _pathToContextMap.values.map((context) => context.dispose()),
    );
    await _runtime.cleanupAll();

    if (_logSink != null) {
      await _logSink!.close();
    }

    _pathToContextMap.clear();
  }
}
