# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0

### Added

- Analyzer plugin that automatically starts `build_runner watch` in the background.
- Automatic process lifecycle management — starts on `part` directive detection, stops on analyzer shutdown.
- Structured logging of all `build_runner` stdout and stderr output to a log file (`build_runner_hook.log` in the system temp directory).
- `--delete-conflicting-outputs` and `--low-resources-mode` flags enabled by default.
- Example project demonstrating usage with `dart_mappable`.
