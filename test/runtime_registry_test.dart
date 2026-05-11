import 'dart:io' as io;

import 'package:build_runner_hook/runtime_registry.dart';
import 'package:build_runner_hook/utils.dart';
import 'package:test/test.dart';

void main() {
  late TempDirectory temp;

  setUp(() async {
    temp = TempDirectory.resolveFor(
      "build_runner_hook_test_${DateTime.now().microsecondsSinceEpoch}",
    );
    await temp.asDirectory.create(recursive: true);
  });

  tearDown(() async {
    if (await temp.asDirectory.exists()) {
      await temp.asDirectory.delete(recursive: true);
    }
  });

  group("packageKeyForRootPath", () {
    test("keeps duplicate package names distinct", () {
      final first = RuntimeRegistry.packageKeyForRootPath("/repo/apps/app");
      final second = RuntimeRegistry.packageKeyForRootPath(
        "/repo/packages/app",
      );

      expect(first, isNot(second));
      expect(first, startsWith("app_"));
      expect(second, startsWith("app_"));
    });

    test("sanitizes unsafe basename characters", () {
      final key = RuntimeRegistry.packageKeyForRootPath("/repo/my app!");

      expect(key, matches(RegExp(r"^[A-Za-z0-9._-]+$")));
      expect(key, startsWith("my_app__"));
    });
  });

  group("owners", () {
    test("keeps build_runner alive while another owner is active", () async {
      const rootPath = "/repo/app";
      final alivePids = {100, 200};
      final killedPids = <int>[];

      final firstRegistry = RuntimeRegistry(
        temp,
        ownerPid: 100,
        isProcessAlive: alivePids.contains,
        killProcess: (pid) {
          killedPids.add(pid);
          return true;
        },
      );
      final secondRegistry = RuntimeRegistry(
        temp,
        ownerPid: 200,
        isProcessAlive: alivePids.contains,
        killProcess: (pid) {
          killedPids.add(pid);
          return true;
        },
      );

      await firstRegistry.registerOwner(rootPath);
      await secondRegistry.registerOwner(rootPath);
      await firstRegistry.recordBuildRunnerPid(rootPath, 900);

      await firstRegistry.removeOwner(rootPath);
      await firstRegistry.cleanupPackage(rootPath);

      final runtime = firstRegistry.packageRuntime(rootPath);
      expect(killedPids, isEmpty);
      expect(await runtime.pidsFile.exists(), isTrue);

      await secondRegistry.removeOwner(rootPath);
      await secondRegistry.cleanupPackage(rootPath);

      expect(killedPids, [900]);
      expect(await runtime.pidsFile.exists(), isFalse);
    });

    test("removes stale owners before cleanup", () async {
      const rootPath = "/repo/app";
      final killedPids = <int>[];
      final registry = RuntimeRegistry(
        temp,
        ownerPid: 100,
        isProcessAlive: (_) => false,
        killProcess: (pid) {
          killedPids.add(pid);
          return true;
        },
      );

      await registry.registerOwner(rootPath);
      await registry.recordBuildRunnerPid(rootPath, 901);
      await registry.cleanupPackage(rootPath);

      final runtime = registry.packageRuntime(rootPath);
      expect(await runtime.ownerFile(100).exists(), isFalse);
      expect(killedPids, [901]);
    });

    test("ignores malformed owner files and pid rows", () async {
      const rootPath = "/repo/app";
      final killedPids = <int>[];
      final registry = RuntimeRegistry(
        temp,
        ownerPid: 100,
        isProcessAlive: (_) => false,
        killProcess: (pid) {
          killedPids.add(pid);
          return true;
        },
      );
      final runtime = registry.packageRuntime(rootPath);

      await runtime.ownersDirectory.create(recursive: true);
      await io.File("${runtime.ownersDirectory.path}/bad.owner").writeAsString(
        "not a pid",
      );
      await runtime.pidsFile.create(recursive: true);
      await runtime.pidsFile.writeAsString("abc\n\n902\n");

      await registry.cleanupPackage(rootPath);

      expect(
        await io.File("${runtime.ownersDirectory.path}/bad.owner").exists(),
        isFalse,
      );
      expect(killedPids, [902]);
    });
  });
}
