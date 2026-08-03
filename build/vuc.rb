class Vuc < Formula
  desc "VUC — Vector Universal Compression (#1 lossless engine, 55.7% ratio)"
  homepage "https://mejustmeb.github.io/VUCE"
  url "https://github.com/Mejustmeb/VUCE/releases/download/v#{version}/vlzx"
  version "1.0.0"
  sha256 "9c14de09ccbe4d1589f9558ba5e28be1e069267eda2120c0919905c6c8219501"

  def install
    bin.install "vlzx"
    man1.install "vlzx.1"
    doc.install "LICENSE.md"
  end

  test do
    system "#{bin}/vlzx", "--help"
  end
end
