# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.2.0

### Added

- Dart workspace support. When the plugin detects a workspace, it starts `build_runner watch --workspace` from the workspace root.
- A `build_runner` dependency check before startup. The plugin now skips startup and logs a helpful message when `build_runner` is not available in the current analysis context.
- Separate log files for plugin lifecycle events and `build_runner` process output to make troubleshooting easier.

### Changed

- The main plugin log file has been renamed to `brh.log`.
- `build_runner` output is now written to package-specific log files named `brh_<package>.log`.
- Workspace and package detection now uses analyzer context information instead of relying only on raw filesystem paths.

## 1.1.0

### Changed

- Removed hardcoded `--delete-conflicting-outputs` and `--low-resources-mode` flags from the `build_runner watch` command; the process now runs with default arguments only.
- Updated installation instructions and removed the configuration section from README.


## 1.0.0

### Added

- Analyzer plugin that automatically starts `build_runner watch` in the background.
- Automatic process lifecycle management — starts on `part` directive detection, stops on analyzer shutdown.
- Structured logging of all `build_runner` stdout and stderr output to a log file (`build_runner_hook.log` in the system temp directory).
- `--delete-conflicting-outputs` and `--low-resources-mode` flags enabled by default.
- Example project demonstrating usage with `dart_mappable`.
