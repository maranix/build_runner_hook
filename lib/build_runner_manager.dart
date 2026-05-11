import 'dart:async';
import 'dart:io' as io;

import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:build_runner_hook/build_runner_tracker.dart';
import 'package:build_runner_hook/config.dart';
import 'package:build_runner_hook/process_context.dart';
import 'package:build_runner_hook/utils.dart';

final class BuildRunnerManager {
  BuildRunnerManager(TempDirectory temp)
    : _temp = temp,
      _log = TempFile.fromPath(temp.asDirectory.path, "./brh.log") {
    _tracker = BuildRunnerTracker(temp, log: _logMessage);

    if (!_temp.asDirectory.existsSync()) {
      _temp.asDirectory.createSync();
    }
  }

  final TempDirectory _temp;
  final TempFile _log;
  late final BuildRunnerTracker _tracker;

  io.IOSink? _logSink;

  final Map<String, ProcessContext> _pathToContextMap = {};
  final Set<String> _pendingRootPaths = {};

  bool get isInitialized => _logSink != null;

  Future<void> init() async {
    if (isInitialized) return;

    try {
      await _initializeLog();
      await _tracker.cleanupAll();
      await _tracker.startDetachedWatchdog();
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
      await _tracker.registerOwner(path);

      final config = await HookConfig.resolve(path);

      final processContext = ProcessContext(
        ctx,
        temp: _temp,
        log: _logMessage,
        onStarted: _onProcessStarted,
        buildFilters: config.buildFilters,
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

  void _onProcessStarted(ProcessContext context, int pid) {
    unawaited(_tracker.recordBuildRunnerPid(context.rootPath, pid));
    _logMessage("${context.rootPath} build_runner started with pid $pid");
  }

  Future<void> dispose() async {
    await _tracker.startDetachedCleanup();
    await Future.wait(_pathToContextMap.keys.map(_tracker.removeOwner));
    await Future.wait(
      _pathToContextMap.values.map((context) => context.dispose()),
    );
    await _tracker.cleanupAll();

    if (_logSink != null) {
      await _logSink!.close();
    }

    _pathToContextMap.clear();
  }
}
