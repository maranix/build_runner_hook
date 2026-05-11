import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _ownerExtension = ".owner";
const _ownersDirectoryName = "owners";
const _pidsFilename = "build_runner.pids";

Future<void> main(List<String> args) async {
  if (args.length < 2) exit(64);

  final tempDirectory = Directory(args[0]);
  final ownerPid = int.tryParse(args[1]);
  if (ownerPid == null) exit(64);
  final watchOwner = args.contains("--watch");

  if (watchOwner) {
    await _waitForProcessExit(ownerPid);
  }

  if (!await tempDirectory.exists()) return;

  await for (final entity in tempDirectory.list()) {
    if (entity is! Directory) continue;
    await _cleanupPackageDirectory(entity, ownerPid);
  }
}

Future<void> _waitForProcessExit(int pid) async {
  while (await _isProcessAlive(pid)) {
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}

Future<void> _cleanupPackageDirectory(Directory directory, int ownerPid) async {
  final ownersDirectory = Directory(
    _join(directory.path, _ownersDirectoryName),
  );
  final ownerFile = File(
    _join(ownersDirectory.path, "$ownerPid$_ownerExtension"),
  );

  if (await ownerFile.exists()) {
    await ownerFile.delete();
  }

  final liveOwners = await _removeStaleOwners(ownersDirectory);
  if (liveOwners > 0) return;

  final pidsFile = File(_join(directory.path, _pidsFilename));
  final pids = await _readBuildRunnerPids(pidsFile);
  for (final pid in pids) {
    try {
      Process.killPid(pid);
    } catch (_) {}
  }

  if (await pidsFile.exists()) {
    await pidsFile.delete();
  }
}

Future<int> _removeStaleOwners(Directory ownersDirectory) async {
  if (!await ownersDirectory.exists()) return 0;

  var liveOwners = 0;
  await for (final entity in ownersDirectory.list()) {
    if (entity is! File) continue;

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

Future<List<int>> _readBuildRunnerPids(File file) async {
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

int? _ownerPidFromFile(File file) {
  final name = file.uri.pathSegments.last;
  if (!name.endsWith(_ownerExtension)) return null;

  return int.tryParse(name.substring(0, name.length - _ownerExtension.length));
}

Future<bool> _isProcessAlive(int pid) async {
  if (pid <= 0) return false;

  try {
    if (Platform.isWindows) {
      final result = await Process.run(
        "tasklist",
        ["/FI", "PID eq $pid", "/NH"],
      );

      return result.exitCode == 0 && result.stdout.toString().contains("$pid");
    }

    final result = await Process.run("kill", ["-0", "$pid"]);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

String _join(String parent, String child) {
  if (parent.endsWith(Platform.pathSeparator)) return "$parent$child";
  return "$parent${Platform.pathSeparator}$child";
}
