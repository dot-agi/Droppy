cask "droppy" do
  version "2.1.4"
  sha256 "3914ec43974a63eb9caa273da618e950262415dbe754fc834c52e95573f2d93e"

  url "https://raw.githubusercontent.com/iordv/Droppy/main/Droppy-2.1.4.dmg"
  name "Droppy"
  desc "Drag and drop file shelf for macOS"
  homepage "https://github.com/iordv/Droppy"

  app "Droppy.app"

  zap trash: [
    "~/Library/Application Support/Droppy",
    "~/Library/Preferences/iordv.Droppy.plist",
  ]
end
