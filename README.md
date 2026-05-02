# build_runner_hook

[![Pub Version](https://img.shields.io/pub/v/build_runner_hook)](https://pub.dev/packages/build_runner_hook)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

An [analyzer plugin](https://dart.dev/tools/analysis) that automatically runs [`build_runner watch`](https://pub.dev/packages/build_runner) in the background when your IDE opens a Dart or Flutter project. It also detects Dart workspaces and starts `build_runner` in workspace mode when needed.

## Features

- **Zero-friction code generation** — `build_runner watch` starts automatically when the analyzer detects a `part` directive, keeping generated files in sync as you code.
- **Workspace-aware startup** — In Dart workspaces, the plugin starts `build_runner watch --workspace` from the workspace root.
- **Dependency guard** — Startup is skipped when `build_runner` is not available in the current package or workspace, and the reason is logged.
- **Runs in the background** — No terminal windows to manage. The plugin spawns and manages the `build_runner` process for you.
- **Graceful lifecycle** — The process is cleanly stopped when the analyzer shuts down.
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
  build_runner_hook: ^1.2.0
```

That's it. The next time your IDE restarts the analysis server, the plugin will start automatically when it encounters a `part` directive in your source files.

### How startup works

- Regular package: runs `dart run build_runner watch`
- Dart workspace: runs `dart run build_runner watch --workspace`

If `build_runner` is not present in the active analysis context, startup is skipped.

## Logs & Troubleshooting

The plugin writes plugin lifecycle events and `build_runner` process output to separate log files. These are the first places to check if code generation is not working as expected.

### Log file location

The log files are written to your system's temporary directory:

| OS      | Path                                           |
| ------- | ---------------------------------------------- |
| macOS   | `$TMPDIR/brh.log` and `$TMPDIR/brh_<package>.log` |
| Linux   | `$TMPDIR/brh.log` and `$TMPDIR/brh_<package>.log` |
| Windows | `%TEMP%\brh.log` and `%TEMP%\brh_<package>.log` |

### Viewing logs

**Tail the plugin log (macOS / Linux):**

```bash
tail -f $TMPDIR/brh.log
```

**Tail a package `build_runner` log:**

```bash
tail -f $TMPDIR/brh_<package>.log
```

**View the full plugin log:**

```bash
cat $TMPDIR/brh.log
```

> [!NOTE]
> You can also restart the analysis server via `Dart: Restart Analysis Server` to re-trigger the plugin.

### Common issues

| Symptom                         | Likely cause                                      | Fix                                                                                           |
| -------------------------------- | ------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Generated files not updating     | `build_runner` is not in `dev_dependencies`       | Run `dart pub add --dev build_runner`                                                         |
| Plugin not activating            | Missing `plugins` block in `analysis_options.yaml` | Add the installation configuration shown above                                                |
| Plugin starts but skips startup  | Active package or workspace does not expose `build_runner` | Check `brh.log`, then add `build_runner` where the plugin is analyzing from                   |
| `build_runner` crashes on start  | Dependency version conflict                       | Check `brh_<package>.log` for details, then run `dart pub upgrade`                            |
| Workspace not detected correctly | `dart pub workspace list` cannot be resolved      | Verify your Dart SDK setup, then restart the analysis server and inspect `brh.log`            |

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
