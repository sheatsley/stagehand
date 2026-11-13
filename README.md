# Stagehand

A small macOS menu bar app for people who use an iPad as a Sidecar display alongside Stage Manager. It:

- **Reconnects Sidecar** when you log in or unlock your Mac, so you don't have to reconnect from Control Center every time.
- **Saves and restores Stage Manager stages**, so you can get your window groupings back when macOS loses them.

Stagehand sits in the menu bar and uses a native macOS menu, much like Time Machine's.

## Requirements

- A Mac with Apple silicon running macOS 14 (Sonoma) or later
- An iPad that supports Sidecar, signed in to the same Apple Account

## Install

With [Homebrew](https://brew.sh):

```sh
brew install --cask sheatsley/tap/stagehand   # prebuilt app from GitHub Releases
# or
brew install sheatsley/tap/stagehand          # builds from source
```

Using the full name taps `sheatsley/tap` and trusts just this package, which Homebrew 6 and later require for packages outside Homebrew's own repositories.

Or download `Stagehand-X.Y.Z.zip` from [Releases](https://github.com/sheatsley/stagehand/releases) and move `Stagehand.app` to `/Applications`.

Stagehand isn't notarized, so macOS blocks it the first time it opens. Allow it under **System Settings → Privacy & Security → Open Anyway**.

## Usage

| Menu item | What it does |
| --- | --- |
| Reconnect Sidecar | Connects to your iPad now. Also happens automatically at launch and after every unlock. |
| Save Stages | Snapshots Stage Manager's current groupings. |
| Restore Stages | Puts the saved snapshot back and restarts Stage Manager. Windows stay open, and the screen flickers briefly. |
| Open at Login | Starts Stagehand when you log in. |

By default Stagehand connects to the first iPad it finds. To pick a specific one, use the name shown on the iPad under **Settings → General → About**:

```sh
defaults write me.sheatsley.stagehand DeviceName "Ryan's iPad"
```

## Build from source

Requires the Xcode Command Line Tools (`xcode-select --install`).

```sh
make build      # builds build/Stagehand.app
make run        # builds, quits any running copy, and launches
make help       # lists all targets
```

To give the app an icon, add a 1024×1024 `Resources/AppIcon.png`. The build converts it to `.icns` automatically.

## Releasing

Releases are built and published from a Mac. No CI is involved.

1. Move the changes under `[Unreleased]` in `CHANGELOG.md` into a new `## [X.Y.Z]` section, then commit and push to `main`.
2. Run `make release VERSION=X.Y.Z`.

The release script checks that the repo is clean and in sync with GitHub. It then builds and zips the app, makes a signed tag for the commit, and publishes a GitHub release with the zip attached and the changelog section as notes. Finally, it updates the cask and formula in the [sheatsley/tap](https://github.com/sheatsley/homebrew-tap) tap. It runs the tap's checks (`brew style`, `brew audit --strict --online`, `brew livecheck`), then commits with a signature and pushes. If a check fails, the release stays published but the tap is left unchanged. Fix `packaging/homebrew/` and run `scripts/update-tap.sh X.Y.Z <zip sha256>` again.

One-time setup: install the [GitHub CLI](https://cli.github.com) and sign in (`brew install gh`, `gh auth login`, `gh auth setup-git`), then `brew tap sheatsley/tap` and `brew trust sheatsley/tap`. Git must be able to sign commits and tags with your key (YubiKey inserted).

## How it works

- **Sidecar** is driven through Apple's private `SidecarCore` framework, which may change in any macOS update. Thanks to [SidecarLauncher](https://github.com/Ocasio-J/SidecarLauncher) by Jovany Ocasio for documenting it.
- **Stage Manager** stores its groupings in the `com.apple.WindowManager` preferences domain. Save Stages exports that domain to `~/Library/Application Support/Stagehand/WindowManager.plist`. Restore Stages imports the file back and restarts the `WindowManager` process, which launchd relaunches right away.

## License

[MIT](LICENSE) © Ryan Sheatsley
