cask "stagehand" do
  version "__VERSION__"
  sha256 "__ZIP_SHA256__"

  url "https://github.com/sheatsley/stagehand/releases/download/v#{version}/Stagehand-#{version}.zip"
  name "Stagehand"
  desc "Menu bar app that reconnects Sidecar and restores Stage Manager stages"
  homepage "https://github.com/sheatsley/stagehand"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  app "Stagehand.app"

  uninstall quit: "me.sheatsley.stagehand"

  zap trash: [
    "~/Library/Application Support/Stagehand",
    "~/Library/Preferences/me.sheatsley.stagehand.plist",
  ]

  caveats <<~EOS
    Stagehand is not notarized, so macOS will block it the first time it opens.
    Allow it under System Settings → Privacy & Security → Open Anyway.
  EOS
end
