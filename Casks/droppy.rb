cask "droppy" do
  version "1.0"
  sha256 "86b52aefcfd790095a4ec7e73b20c822bf50492a4e52da0f4e57f0914fb1bc0f"

  url "https://raw.githubusercontent.com/iordv/Droppy/main/Droppy.dmg"
  name "Droppy"
  desc "Drag and drop file shelf for macOS"
  homepage "https://github.com/iordv/Droppy"

  app "Droppy.app"

  zap trash: [
    "~/Library/Application Support/Droppy",
    "~/Library/Preferences/iordv.Droppy.plist",
  ]
end
