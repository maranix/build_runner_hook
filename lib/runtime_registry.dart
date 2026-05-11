import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:isolate';

import 'package:build_runner_hook/utils.dart';
import 'package:path/path.dart' as p;

typedef ProcessAlive = FutureOr<bool> Function(int pid);
typedef ProcessKiller = bool Function(int pid);
typedef RuntimeLogger = void Function(String message);

final class RuntimeRegistry {
  RuntimeRegistry(
    this._temp, {
    int? ownerPid,
    DateTime Function()? now,
    ProcessAlive? isProcessAlive,
    ProcessKiller? killProcess,
    RuntimeLogger? log,
  }) : _ownerPid = ownerPid ?? io.pid,
       _now = now ?? DateTime.now,
       _isProcessAlive = isProcessAlive ?? _defaultIsProcessAlive,
       _killProcess = killProcess ?? _defaultKillProcess,
       _log = log;

  static const _ownerExtension = ".owner";
  static const _ownersDirectoryName = "owners";
  static const _pidsFilename = "build_runner.pids";
  static const _cleanupRunnerUri =
      "package:build_runner_hook/cleanup_runner.dart";

  final TempDirectory _temp;
  final int _ownerPid;
  final DateTime Function() _now;
  final ProcessAlive _isProcessAlive;
  final ProcessKiller _killProcess;
  final RuntimeLogger? _log;

  Future<void> ensureRoot() async {
    final directory = _temp.asDirectory;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  Future<void> cleanupAll() async {
    await ensureRoot();

    await for (final entity in _temp.asDirectory.list()) {
      if (entity is! io.Directory) continue;
      await cleanupPackageDirectory(entity);
    }
  }

  Future<void> startDetachedCleanup() async {
    await _startDetachedCleanup(waitForOwnerExit: false);
  }

  Future<void> startDetachedWatchdog() async {
    await _startDetachedCleanup(waitForOwnerExit: true);
  }

  Future<void> _startDetachedCleanup({required bool waitForOwnerExit}) async {
    final cleanupUri = await Isolate.resolvePackageUri(
      Uri.parse(_cleanupRunnerUri),
    );
    if (cleanupUri == null) {
      _log?.call("Unable to resolve cleanup runner");
      return;
    }

    await io.Process.start(
      io.Platform.resolvedExecutable,
      [
        cleanupUri.toFilePath(),
        _temp.asDirectory.path,
        "$_ownerPid",
        if (waitForOwnerExit) "--watch",
      ],
      mode: .detached,
    );
  }

  Future<void> registerOwner(String rootPath) async {
    final runtime = packageRuntime(rootPath);
    await runtime.ownersDirectory.create(recursive: true);

    final ownerFile = runtime.ownerFile(_ownerPid);
    await ownerFile.writeAsString(
      [
        "root=${p.normalize(rootPath)}",
        "pid=$_ownerPid",
        "createdAt=${_now().toIso8601String()}",
        "",
      ].join("\n"),
      mode: .writeOnly,
      flush: true,
    );
  }

  Future<void> removeOwner(String rootPath) async {
    final ownerFile = packageRuntime(rootPath).ownerFile(_ownerPid);
    if (await ownerFile.exists()) {
      await ownerFile.delete();
    }
  }

  Future<void> recordBuildRunnerPid(String rootPath, int pid) async {
    final runtime = packageRuntime(rootPath);
    await runtime.directory.create(recursive: true);

    final sink = runtime.pidsFile.openWrite(mode: io.FileMode.writeOnlyAppend);
    sink.writeln(pid);
    await sink.close();
  }

  Future<void> cleanupPackage(String rootPath) {
    return cleanupPackageDirectory(packageRuntime(rootPath).directory);
  }

  Future<void> cleanupPackageDirectory(io.Directory directory) async {
    final runtime = PackageRuntime.fromDirectory(directory);

    final liveOwners = await _removeStaleOwners(runtime);
    if (liveOwners > 0) {
      _log?.call("${runtime.key} has $liveOwners active owner(s); skipping");
      return;
    }

    final pids = await _readBuildRunnerPids(runtime.pidsFile);
    for (final pid in pids) {
      final killed = _killProcess(pid);
      if (killed) {
        _log?.call("${runtime.key} killed build_runner pid $pid");
      } else {
        _log?.call("${runtime.key} unable to kill build_runner pid $pid");
      }
    }

    if (await runtime.pidsFile.exists()) {
      await runtime.pidsFile.delete();
    }
  }

  PackageRuntime packageRuntime(String rootPath) {
    final key = packageKeyForRootPath(rootPath);
    return PackageRuntime.fromDirectory(_temp.directory(key));
  }

  static String packageKeyForRootPath(String rootPath) {
    final normalized = p.normalize(rootPath);
    final basename = p.basename(normalized);
    final safeName = _sanitizeName(basename.isEmpty ? "package" : basename);
    final hash = _fnv1a32(normalized).toRadixString(16).padLeft(8, "0");

    return "${safeName}_$hash";
  }

  static String _sanitizeName(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      final isUpper = codeUnit >= 65 && codeUnit <= 90;
      final isLower = codeUnit >= 97 && codeUnit <= 122;
      final isSafeSymbol = codeUnit == 45 || codeUnit == 46 || codeUnit == 95;

      buffer.write(
        isDigit || isUpper || isLower || isSafeSymbol
            ? String.fromCharCode(codeUnit)
            : "_",
      );
    }

    final sanitized = buffer.toString();
    return sanitized.isEmpty ? "package" : sanitized;
  }

  static int _fnv1a32(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in utf8.encode(value)) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    return hash;
  }

  Future<int> _removeStaleOwners(PackageRuntime runtime) async {
    final ownersDirectory = runtime.ownersDirectory;
    if (!await ownersDirectory.exists()) return 0;

    var liveOwners = 0;
    await for (final entity in ownersDirectory.list()) {
      if (entity is! io.File) continue;

      final pid = _ownerPidFromFile(entity);
      if (pid == null) {
        await entity.delete();
        continue;
      }

      final isAlive = await _isProcessAlive(pid);
      if (isAlive) {
        liveOwners += 1;
      } else {
        await entity.delete();
      }
    }

    return liveOwners;
  }

  Future<List<int>> _readBuildRunnerPids(io.File file) async {
    if (!await file.exists()) return const [];

    final pids = <int>[];
    await for (final line
        in file
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final pid = int.tryParse(line.trim());
      if (pid == null) continue;

      pids.add(pid);
    }

    return pids;
  }

  int? _ownerPidFromFile(io.File file) {
    final basename = p.basename(file.path);
    if (!basename.endsWith(_ownerExtension)) return null;

    final pidText = basename.substring(
      0,
      basename.length - _ownerExtension.length,
    );

    return int.tryParse(pidText);
  }

  static Future<bool> _defaultIsProcessAlive(int pid) async {
    if (pid <= 0) return false;
    if (pid == io.pid) return true;

    try {
      if (io.Platform.isWindows) {
        final result = await io.Process.run(
          "tasklist",
          ["/FI", "PID eq $pid", "/NH"],
        );

        return result.exitCode == 0 &&
            result.stdout.toString().contains("$pid");
      }

      final result = await io.Process.run("kill", ["-0", "$pid"]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static bool _defaultKillProcess(int pid) {
    try {
      return io.Process.killPid(pid);
    } catch (_) {
      return false;
    }
  }
}

final class PackageRuntime {
  const PackageRuntime._(this.directory);

  factory PackageRuntime.fromDirectory(io.Directory directory) {
    return PackageRuntime._(directory);
  }

  final io.Directory directory;

  String get key => p.basename(directory.path);

  io.Directory get ownersDirectory => io.Directory(
    p.normalize(p.join(directory.path, RuntimeRegistry._ownersDirectoryName)),
  );

  io.File get pidsFile => io.File(
    p.normalize(p.join(directory.path, RuntimeRegistry._pidsFilename)),
  );

  io.File ownerFile(int pid) => io.File(
    p.normalize(
      p.join(
        ownersDirectory.path,
        "$pid${RuntimeRegistry._ownerExtension}",
      ),
    ),
  );
}
