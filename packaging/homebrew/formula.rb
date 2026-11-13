class Stagehand < Formula
  desc "Menu bar app that reconnects Sidecar and restores Stage Manager stages"
  homepage "https://github.com/sheatsley/stagehand"
  url "https://github.com/sheatsley/stagehand/archive/refs/tags/v__VERSION__.tar.gz"
  sha256 "__SRC_SHA256__"
  license "MIT"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  def install
    ENV["STAGEHAND_VERSION"] = version.to_s
    ENV["STAGEHAND_COMMIT"] = "v#{version}"
    ENV["SWIFT_BUILD_FLAGS"] = "--disable-sandbox"
    system "scripts/build.sh"
    prefix.install "build/Stagehand.app"
  end

  def caveats
    <<~EOS
      Stagehand.app was built and installed to:
        #{opt_prefix}/Stagehand.app

      To make it show up in Spotlight and Launchpad, link it into ~/Applications:
        ln -sf #{opt_prefix}/Stagehand.app ~/Applications/Stagehand.app
    EOS
  end

  test do
    assert_path_exists prefix/"Stagehand.app/Contents/MacOS/Stagehand"
  end
end
