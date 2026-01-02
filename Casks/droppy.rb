cask "droppy" do
  version "1.0"
  sha256 "81b4e5e4e4554f9af21a65755b87ef9fccf7a1a178ee76243488bbc3ec6102b7"

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
