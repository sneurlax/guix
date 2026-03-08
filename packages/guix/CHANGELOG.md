# Changelog

## 0.0.2

- `setup` command now fetches the Android SDK (cmdline-tools download,
  license acceptance, and sdkmanager component installation via Guix shell).
- Fixed CLI `--version` reporting wrong version string.
- Removed unused `--pinned` flag from `setup` command.
- Added tests for `init`, `doctor`, `pin`, `build`, `shell`, and `clean`
  commands.

## 0.0.1

- Initial release.
- `init` command: generate `guix.yaml`, platform manifests, and pin channels.
- `setup` command: fetch Flutter SDK with optional SHA-256 verification.
- `shell` command: enter an interactive Guix development shell.
- `build` command: run a reproducible build inside a Guix environment.
- `doctor` command: check prerequisites and configuration.
- `pin` command: update `guix/channels.scm` from current Guix state.
- `clean` command: remove fetched SDKs and build artifacts.
- `eject` command: generate standalone shell scripts and a Makefile.
