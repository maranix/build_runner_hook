import 'dart:io' as io;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

final class HookConfig {
  const HookConfig({this.buildFilters = const []});

  final List<String> buildFilters;

  factory HookConfig.fromYaml(String yaml) {
    final doc = loadYaml(yaml);
    if (doc is! YamlMap) return const HookConfig();

    final buildFilters = doc['build_filter'];
    if (buildFilters is! YamlList) return const HookConfig();

    return HookConfig(
      buildFilters: buildFilters.whereType<String>().toList(),
    );
  }

  static Future<HookConfig> resolve(String rootPath) async {
    var current = io.Directory(rootPath);

    while (true) {
      final configFile = io.File(
        p.join(current.path, 'build_runner_hook.yaml'),
      );
      if (await configFile.exists()) {
        try {
          final content = await configFile.readAsString();
          return HookConfig.fromYaml(content);
        } catch (_) {
          return const HookConfig();
        }
      }

      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }

    return const HookConfig();
  }
}
