# Package-Scoped Cleanup Progress

- [x] Create local progress tracker.
- [x] Add package-scoped runtime registry.
- [x] Wire analyzer ownership into `BuildRunnerManager`.
- [x] Remove project-resolved cleanup executable path.
- [x] Add focused unit tests.
- [x] Run tests and static analysis.
- [x] Add internal detached shutdown cleanup runner so cleanup can continue after analyzer/plugin process teardown starts.
- [x] Move detached cleanup to a startup-launched watchdog because analyzer/plugin shutdown is not reliably invoked before the process exits.
