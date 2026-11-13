# Changelog

All notable changes to Stagehand are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-11-13

### Added

- Restores saved stages automatically after Sidecar reconnects, at login, on unlock, and when switching back to your account.
- The menu shows when the last stage restore failed; hover over it to see why.
- Logging to `~/Library/Logs/Stagehand/stagehand.log`, capped at about 1 MB.
- Screenshots in the README.

### Fixed

- Reconnect Sidecar no longer reports a failure when the iPad is already connected, on macOS versions where SidecarCore can report connected devices.

### Changed

- The About window now opens in front of other windows without Stage Manager moving them aside, and closes with ⌘W or Esc.

## [0.1.0] - 2026-11-13

### Added

- Menu bar app with a native macOS menu.
- Reconnects the iPad over Sidecar at launch and whenever the screen unlocks, with a manual Reconnect Sidecar action.
- Save Stages and Restore Stages for Stage Manager, which snapshot and restore its settings and restart its process.
- Open at Login toggle.
- About window with version, build, and license details.

[Unreleased]: https://github.com/sheatsley/stagehand/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sheatsley/stagehand/releases/tag/v0.1.0
