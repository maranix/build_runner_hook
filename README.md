# build_runner_hook

[![Pub Version](https://img.shields.io/pub/v/build_runner_hook)](https://pub.dev/packages/build_runner_hook)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

An [analyzer plugin](https://dart.dev/tools/analysis) that automatically runs [`build_runner watch`](https://pub.dev/packages/build_runner) in the background when your IDE opens a Dart or Flutter project. It also detects Dart workspaces and starts `build_runner` in workspace mode when needed.

## Features

- **Zero-friction code generation** — `build_runner watch` starts automatically when the analyzer detects a `part` directive, keeping generated files in sync as you code.
- **Workspace-aware startup** — In Dart workspaces, the plugin starts `build_runner watch --workspace` from the workspace root.
- **Dependency guard** — Startup is skipped when `build_runner` is not available in the current package or workspace, and the reason is logged.
- **Runs in the background** — No terminal windows to manage. The plugin spawns and manages the `build_runner` process for you.
- **Package-scoped cleanup** — Multiple IDE windows can share a package safely; `build_runner` is stopped only after the last analyzer instance for that package exits.
- **Structured logging** — Plugin lifecycle events and `build_runner` output are written to separate timestamped log files for easier debugging.

## Getting Started

### Prerequisites

- Dart SDK `^3.11.0`
- A project that uses [`build_runner`](https://pub.dev/packages/build_runner) for code generation (e.g., `json_serializable`, `freezed`, `dart_mappable`, etc.)

### Installation

Enable the plugin in your project's `analysis_options.yaml`:

```yaml
# analysis_options.yaml

plugins:
  build_runner_hook: ^2.0.0
```

That's it. The next time your IDE restarts the analysis server, the plugin will start automatically when it encounters a `part` directive in your source files.

## Configuration

You can customize the plugin by adding a `build_runner_hook.yaml` file in your project root or any parent directory. The configuration structure is designed to be intuitive and closely follows the `build_runner` CLI options.

### `build_filter`

Maps directly to the `--build-filter` option of the `build_runner` CLI. It limits which files get built, and multiple filters are ORed together.

```yaml
# build_runner_hook.yaml
build_filter:
  - "lib/models/*.g.dart"
  - "test/**"
```

## How startup works

- Regular package: runs `dart run build_runner watch`
- Dart workspace: runs `dart run build_runner watch --workspace`

If `build_runner` is not present in the active analysis context, startup is skipped.

### How cleanup works

The plugin records runtime state per package in the system temp directory. Each analyzer instance gets its own owner marker, and each package records the `build_runner` PIDs it started.

When an analyzer instance starts, the plugin also starts a detached cleanup watchdog. The watchdog waits for that analyzer process to exit, removes only that instance's owner marker, and stops `build_runner` for a package only when no other live owner remains. This keeps code generation running when the same package is open in multiple IDE windows.

## Logs & Troubleshooting

The plugin writes plugin lifecycle events and `build_runner` process output to separate log files. These are the first places to check if code generation is not working as expected.

### Log file location

The plugin organizes state and logs into package-specific directories within your system's temporary directory. Each package you open gets its own unique directory named `<package_name>_<hash>`.

| OS      | Path                                                                     |
| ------- | ------------------------------------------------------------------------ |
| macOS   | `$TMPDIR/build_runner_hook/<package_dir>/hook.log` and `build_runner.log` |
| Linux   | `/tmp/build_runner_hook/<package_dir>/hook.log` and `build_runner.log`    |
| Windows | `%TEMP%\build_runner_hook\<package_dir>\hook.log` and `build_runner.log` |

### Viewing logs

**Tail the plugin lifecycle log (macOS / Linux):**

```bash
# Replace <package_dir> with your project's specific directory
tail -f $TMPDIR/build_runner_hook/<package_dir>/hook.log
```

**Tail the `build_runner` process output:**

```bash
tail -f $TMPDIR/build_runner_hook/<package_dir>/build_runner.log
```

**Quickly find your log directory:**

```bash
ls -dt $TMPDIR/build_runner_hook/*/ | head -n 1
```

> [!NOTE]
> The `<package_dir>` follows the format `name_hash` (e.g., `my_app_a1b2c3d4`). If you have multiple packages with the same name, the hash ensures they don't collide.

> [!NOTE]
> You can also restart the analysis server via `Dart: Restart Analysis Server` to re-trigger the plugin.

### Common issues

| Symptom                         | Likely cause                                      | Fix                                                                                           |
| -------------------------------- | ------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Generated files not updating     | `build_runner` is not in `dev_dependencies`       | Run `dart pub add --dev build_runner`                                                         |
| Plugin not activating            | Missing `plugins` block in `analysis_options.yaml` | Add the installation configuration shown above                                                |
| Plugin starts but skips startup  | Active package or workspace does not expose `build_runner` | Check `hook.log`, then add `build_runner` where the plugin is analyzing from                   |
| `build_runner` crashes on start  | Dependency version conflict                       | Check `build_runner.log` for details, then run `dart pub upgrade`                             |
| Workspace not detected correctly | `dart pub workspace list` cannot be resolved      | Verify your Dart SDK setup, then restart the analysis server and inspect `hook.log`            |

## Example

A working example project is available in the [`example/`](https://github.com/maranix/build_runner_hook/tree/main/example) directory. It demonstrates the plugin with [`dart_mappable`](https://pub.dev/packages/dart_mappable) for code generation.

## Contributing

Contributions are welcome! Please feel free to submit a [Pull Request](https://github.com/maranix/build_runner_hook/pulls).

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

Please ensure your code follows the project's analysis rules and that all tests pass:

```bash
dart analyze
dart test
```

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
