import 'dart:io' as io;
import 'dart:isolate';

import 'package:build_runner_hook/utils.dart';
import 'package:path/path.dart' as p;

final class BuildRunnerTracker {
  BuildRunnerTracker(this._temp);

  static const _cleanupRunnerUri =
      "package:build_runner_hook/cleanup_runner.dart";

  final TempDirectory _temp;
  final int _ownerPid = io.pid;

  Future<void> cleanupAll() async {
    final directory = _temp.asDirectory;
    if (!await directory.exists()) return;

    await for (final entity in directory.list()) {
      if (entity is io.Directory) {
        await cleanupPackage(entity.path, isPackageDir: true);
      }
    }
  }

  Future<void> startDetachedCleanup() async {
    await _startDetached(waitForOwnerExit: false);
  }

  Future<void> startDetachedWatchdog() async {
    await _startDetached(waitForOwnerExit: true);
  }

  Future<void> _startDetached({required bool waitForOwnerExit}) async {
    final cleanupUri = await Isolate.resolvePackageUri(
      Uri.parse(_cleanupRunnerUri),
    );
    if (cleanupUri == null) return;

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
    final ownersDir = io.Directory(p.join(packageDir(rootPath), "owners"));
    await ownersDir.create(recursive: true);

    final ownerFile = io.File(p.join(ownersDir.path, "$_ownerPid.owner"));
    await ownerFile.writeAsString(
      "root=${p.normalize(rootPath)}\npid=$_ownerPid\n",
      mode: .writeOnly,
      flush: true,
    );
  }

  Future<void> removeOwner(String rootPath) async {
    final ownerFile = io.File(
      p.join(packageDir(rootPath), "owners", "$_ownerPid.owner"),
    );
    if (await ownerFile.exists()) {
      await ownerFile.delete();
    }
  }

  Future<void> recordBuildRunnerPid(String rootPath, int pid) async {
    final pidsFile = io.File(p.join(packageDir(rootPath), "build_runner.pids"));
    await pidsFile.create(recursive: true);

    final sink = pidsFile.openWrite(mode: .writeOnlyAppend);
    sink.writeln(pid);
    await sink.close();
  }

  Future<void> cleanupPackage(String path, {bool isPackageDir = false}) async {
    final packageDirStr = isPackageDir ? path : packageDir(path);
    final ownersDir = io.Directory(p.join(packageDirStr, "owners"));

    var liveOwners = 0;
    if (await ownersDir.exists()) {
      await for (final entity in ownersDir.list()) {
        if (entity is! io.File || !entity.path.endsWith('.owner')) continue;

        final pidString = p.basename(entity.path).replaceAll('.owner', '');
        final pid = int.tryParse(pidString);

        if (pid != null && await _isProcessAlive(pid)) {
          liveOwners++;
        } else {
          await entity.delete();
        }
      }
    }

    if (liveOwners > 0) return;

    final pidsFile = io.File(p.join(packageDirStr, "build_runner.pids"));
    if (await pidsFile.exists()) {
      final lines = await pidsFile.readAsLines();
      for (final line in lines) {
        final pid = int.tryParse(line.trim());
        if (pid != null) {
          try {
            io.Process.killPid(pid);
          } catch (_) {}
        }
      }
      await pidsFile.delete();
    }
  }

  String packageDir(String rootPath) {
    final normalized = p.normalize(rootPath);
    final name = p.basename(normalized);
    final hash = normalized.hashCode.toRadixString(16);

    return p.join(
      _temp.asDirectory.path,
      "${name.isEmpty ? "root" : name}_$hash",
    );
  }

  static Future<bool> _isProcessAlive(int pid) async {
    if (pid <= 0) return false;
    if (pid == io.pid) return true;

    try {
      if (io.Platform.isWindows) {
        final result = await io.Process.run("tasklist", [
          "/FI",
          "PID eq $pid",
          "/NH",
        ]);
        return result.exitCode == 0 &&
            result.stdout.toString().contains("$pid");
      }
      final result = await io.Process.run("kill", ["-0", "$pid"]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
