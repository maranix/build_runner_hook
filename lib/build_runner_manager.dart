import 'dart:async';
import 'dart:io';

final _logUri = Directory.systemTemp.uri;
final _pluginLogUri = _logUri.resolve("./brh.log");

final class BuildRunnerManager {
  BuildRunnerManager()
    : _pluginLog = File(
        _pluginLogUri.toFilePath(),
      ) {
    if (_pluginLog.existsSync()) {
      _pluginLog.deleteSync();
    }
  }

  final File _pluginLog;

  Future<void> stop() async {
    logPlugin("Stopping Build Runner");
    logPlugin("Waiting for 5 seconds");
    logPlugin("Build Runner stopped");
  }

  void logPlugin(String message) {
    final timestamp = DateTime.now();
    _pluginLog.writeAsStringSync(
      "\nTimestamp $timestamp\t$message",
      mode: .writeOnlyAppend,
    );
  }
}
