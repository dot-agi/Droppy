cask "droppy" do
  version "2.0.2"
  sha256 "cc231e86975d8392a88986ffb47998605478719306660d5f4931413f6e97a701"

  url "https://raw.githubusercontent.com/iordv/Droppy/main/Droppy-2.0.2.dmg"
  name "Droppy"
  desc "Drag and drop file shelf for macOS"
  homepage "https://github.com/iordv/Droppy"

  app "Droppy.app"

  zap trash: [
    "~/Library/Application Support/Droppy",
    "~/Library/Preferences/iordv.Droppy.plist",
  ]
end
