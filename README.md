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
brew tap sheatsley/formulae
brew install --cask stagehand      # prebuilt app from GitHub Releases
# or
brew install stagehand             # builds from source
```

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

The release script checks that the repo is clean and in sync with GitHub. It then builds and zips the app, tags the commit, and publishes a GitHub release with the zip attached and the changelog section as notes. Finally, it updates the cask and formula in the [sheatsley/formulae](https://github.com/sheatsley/homebrew-formulae) tap. It needs the [GitHub CLI](https://cli.github.com) (`gh auth login`).

## How it works

- **Sidecar** is driven through Apple's private `SidecarCore` framework, which may change in any macOS update. Thanks to [SidecarLauncher](https://github.com/Ocasio-J/SidecarLauncher) by Jovany Ocasio for documenting it.
- **Stage Manager** stores its groupings in the `com.apple.WindowManager` preferences domain. Save Stages exports that domain to `~/Library/Application Support/Stagehand/WindowManager.plist`. Restore Stages imports the file back and restarts the `WindowManager` process, which launchd relaunches right away.

## License

[MIT](LICENSE) © Ryan Sheatsley
