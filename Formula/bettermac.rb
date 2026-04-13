class Bettermac < Formula
  desc "PowerToys-inspired productivity toolkit for macOS"
  homepage "https://github.com/mag-kri/BetterMac"
  head "https://github.com/mag-kri/BetterMac.git", branch: "main"
  license "MIT"

  depends_on xcode: ["14.0", :build]
  depends_on macos: :ventura

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/BetterMac" => "bettermac"
  end

  def caveats
    <<~EOS
      BetterMac needs Accessibility permission to manage windows.

      On first launch:
        1. System Settings > Privacy & Security > Accessibility
        2. Add and enable your terminal app (or bettermac)

      Start with:
        bettermac &
    EOS
  end

  test do
    assert_match "BetterMac", shell_output("#{bin}/bettermac --help 2>&1", 1)
  end
end
