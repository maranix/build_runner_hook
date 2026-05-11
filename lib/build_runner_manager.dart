import 'dart:async';
import 'dart:io' as io;

import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:build_runner_hook/build_runner_tracker.dart';
import 'package:build_runner_hook/config.dart';
import 'package:build_runner_hook/process_context.dart';
import 'package:build_runner_hook/utils.dart';
import 'package:path/path.dart' as p;

final class BuildRunnerManager {
  BuildRunnerManager(TempDirectory temp) : _temp = temp {
    _tracker = BuildRunnerTracker(temp);

    if (!_temp.asDirectory.existsSync()) {
      _temp.asDirectory.createSync();
    }
  }

  final TempDirectory _temp;
  late final BuildRunnerTracker _tracker;

  final Map<String, ProcessContext> _pathToContextMap = {};
  final Set<String> _pendingRootPaths = {};

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    try {
      await _tracker.cleanupAll();
      await _tracker.startDetachedWatchdog();
      _initialized = true;
    } catch (_) {
      // Ignore init errors
    }
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
      final packageDir = _tracker.packageDir(path);

      final processContext = ProcessContext(
        ctx,
        packageDirectory: packageDir,
        log: (msg) => _logPackage(packageDir, msg),
        onStarted: _onProcessStarted,
        buildFilters: config.buildFilters,
      );

      _pathToContextMap[path] = processContext;
      _logPackage(packageDir, "$path registered!");
      unawaited(processContext.start());
    } catch (_) {
      // Ignore registration errors
    } finally {
      _pendingRootPaths.remove(path);
    }
  }

  void _onProcessStarted(ProcessContext context, int pid) {
    unawaited(_tracker.recordBuildRunnerPid(context.rootPath, pid));
    _logPackage(
      _tracker.packageDir(context.rootPath),
      "${context.rootPath} build_runner started with pid $pid",
    );
  }

  void _logPackage(String packageDir, String message) {
    final logFile = io.File(p.join(packageDir, "hook.log"));
    final timestamp = DateTime.now().toIso8601String();
    logFile.writeAsStringSync(
      "TIMESTAMP $timestamp\t$message\n",
      mode: io.FileMode.append,
      flush: true,
    );
  }

  Future<void> dispose() async {
    await _tracker.startDetachedCleanup();
    await Future.wait(_pathToContextMap.keys.map(_tracker.removeOwner));
    await Future.wait(
      _pathToContextMap.values.map((context) => context.dispose()),
    );
    await _tracker.cleanupAll();

    _pathToContextMap.clear();
  }
}
