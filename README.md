# build_runner_hook

[![Pub Version](https://img.shields.io/pub/v/build_runner_hook)](https://pub.dev/packages/build_runner_hook)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

An [analyzer plugin](https://dart.dev/tools/analysis) that automatically runs [`build_runner watch`](https://pub.dev/packages/build_runner) in the background when your IDE opens a Dart or Flutter project — no manual terminal commands needed.

## Features

- **Zero-friction code generation** — `build_runner watch` starts automatically when the analyzer detects a `part` directive, keeping generated files in sync as you code.
- **Runs in the background** — No terminal windows to manage. The plugin spawns and manages the `build_runner` process for you.
- **Graceful lifecycle** — The process is cleanly stopped when the analyzer shuts down.
- **Structured logging** — All `build_runner` stdout/stderr output is written to a timestamped log file for easy debugging.

## Getting Started

### Prerequisites

- Dart SDK `^3.11.0`
- A project that uses [`build_runner`](https://pub.dev/packages/build_runner) for code generation (e.g., `json_serializable`, `freezed`, `dart_mappable`, etc.)

### Installation

Enable the plugin in your project's `analysis_options.yaml`:

```yaml
# analysis_options.yaml

plugins:
  build_runner_hook: ^1.1.0
```

That's it. The next time your IDE restarts the analysis server, `build_runner watch` will start automatically when the plugin encounters a `part` directive in your source files.

## Logs & Troubleshooting

The plugin writes all `build_runner` output (stdout and stderr) to a log file. This is the first place to check if code generation isn't working as expected.

### Log file location

The log file is written to your system's temporary directory:

| OS      | Path                                           |
| ------- | ---------------------------------------------- |
| macOS   | `$TMPDIR/build_runner_hook.log`                  |
| Linux   | `$TMPDIR/build_runner_hook.log`                  |
| Windows | `%TEMP%\build_runner_hook.log`                  |

### Viewing logs

**Tail logs in real-time (macOS / Linux):**

```bash
tail -f $TMPDIR/build_runner_hook.log
```

**View the full log:**

```bash
cat $TMPDIR/build_runner_hook.log
```

> [!NOTE]
> You can also restart the analysis server via `Dart: Restart Analysis Server` to re-trigger the plugin.

### Common issues

| Symptom                             | Likely cause                                   | Fix                                                                                        |
| ----------------------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Generated files not updating        | `build_runner` is not in `dev_dependencies`     | Run `dart pub add --dev build_runner`                                                      |
| Plugin not activating               | Missing `plugins` block in `analysis_options.yaml` | Add the [setup configuration](#setup) shown above                                          |
| `build_runner` crashes on start     | Dependency version conflict                    | Check the log file for details, then run `dart pub upgrade`                                 |
| Stale log file from previous session | Old process was not cleaned up                 | Delete the log file and restart the analysis server                                        |

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
