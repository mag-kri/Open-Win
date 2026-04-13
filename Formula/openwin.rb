class Openwin < Formula
  desc "PowerToys-inspired productivity toolkit for macOS"
  homepage "https://github.com/mag-kri/openwin"
  head "https://github.com/mag-kri/openwin.git", branch: "main"
  license "MIT"

  depends_on xcode: ["14.0", :build]
  depends_on macos: :ventura

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/OpenWin" => "openwin"
  end

  def caveats
    <<~EOS
      OpenWin needs Accessibility permission to manage windows.

      On first launch:
        1. System Settings > Privacy & Security > Accessibility
        2. Add and enable your terminal app (or openwin)

      Start with:
        openwin &
    EOS
  end

  test do
    assert_match "OpenWin", shell_output("#{bin}/openwin --help 2>&1", 1)
  end
end
