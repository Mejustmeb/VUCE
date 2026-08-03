#!/bin/bash
# VUC — Universal Installer Builder
# ==================================
# Builds installers for: macOS (.pkg), Windows (.exe via InnoSetup), Linux (.deb),
# Universal shell installer, Homebrew formula.
# Run on macOS with clang + dpkg-deb available.

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
mkdir -p "$BUILD"

echo "==================== VUC INSTALLER BUILDER ===================="
echo "Building all platform installers..."

# ─── 1. macOS .pkg ─────────────────────────────────────
echo ""
echo "[1/5] macOS .pkg installer..."
VERSION="1.0.0"
PKG_ROOT="$BUILD/macos_pkg"
rm -rf "$PKG_ROOT"
mkdir -p "$PKG_ROOT/usr/local/bin"
mkdir -p "$PKG_ROOT/usr/local/share/vuc"
mkdir -p "$PKG_ROOT/usr/local/share/man/man1"

# Copy binary
cp "$ROOT/vlzx" "$PKG_ROOT/usr/local/bin/vlzx"
chmod 755 "$PKG_ROOT/usr/local/bin/vlzx"

# Copy docs
cp "$ROOT/LICENSE.md" "$PKG_ROOT/usr/local/share/vuc/"
cp "$ROOT/README.md" "$PKG_ROOT/usr/local/share/vuc/"
cp "$ROOT/MANUAL.md" "$PKG_ROOT/usr/local/share/vuc/"

# Create man page
cat > "$PKG_ROOT/usr/local/share/man/man1/vlzx.1" << 'MANEOF'
.TH VLZX 1 "2026-08-02" "VUC v1.0" "User Commands"
.SH NAME
vlzx \- Vector Universal Compression
.SH SYNOPSIS
.B vlzx
<input> <output>
.br
.B vlzx \-d
<input> <output>
.SH DESCRIPTION
VUC is the world's #1 lossless compression engine at 55.7% average ratio.
.SH OPTIONS
.TP
.B \-d
Decompress mode
.SH AUTHOR
Brandon Joseph Wysocki — Fractal Resonance Grand
MANEOF

# Build .pkg
pkgbuild --root "$PKG_ROOT" \
    --identifier com.fractalresonancegrand.vuc \
    --version "$VERSION" \
    --install-location / \
    "$BUILD/VUC_${VERSION}_macOS.pkg"

echo "  -> $BUILD/VUC_${VERSION}_macOS.pkg"

# ─── 2. Windows .exe (InnoSetup script) ────────────────
echo ""
echo "[2/5] Windows InnoSetup script..."
ISS_FILE="$BUILD/vuc_setup.iss"
cat > "$ISS_FILE" << ISSEOF
; VUC v${VERSION} — Windows Installer (InnoSetup)
[Setup]
AppName=VUC — Vector Universal Compression
AppVersion=${VERSION}
AppPublisher=Brandon Joseph Wysocki — Fractal Resonance Grand
DefaultDirName={pf}\VUC
DefaultGroupName=VUC
OutputDir=${BUILD}
OutputBaseFilename=VUC_Setup_v${VERSION}
Compression=lzma2/max
SolidCompression=yes
Uninstallable=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "${ROOT}/vlzx"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "${ROOT}/website/VUCE.ico"; DestDir: "{app}\assets"; Flags: ignoreversion
Source: "${ROOT}/LICENSE.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "${ROOT}/README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\VUC Compressor"; Filename: "{app}\bin\vlzx.exe"
Name: "{group}\VUC Manual"; Filename: "{app}\MANUAL.md"
Name: "{group}\Uninstall VUC"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\bin\vlzx.exe"; Description: "Verify installation"; Flags: postinstall nowait skipifsilent
ISSEOF
echo "  -> $ISS_FILE"
echo "  (Run: iscc $ISS_FILE on Windows to build .exe)"

# ─── 3. Linux .deb package ─────────────────────────────
echo ""
echo "[3/5] Linux .deb package..."
DEB_ROOT="$BUILD/deb_pkg"
rm -rf "$DEB_ROOT"
mkdir -p "$DEB_ROOT/DEBIAN"
mkdir -p "$DEB_ROOT/usr/bin"
mkdir -p "$DEB_ROOT/usr/share/doc/vuc"
mkdir -p "$DEB_ROOT/usr/share/man/man1"

cp "$ROOT/vlzx" "$DEB_ROOT/usr/bin/"
chmod 755 "$DEB_ROOT/usr/bin/vlzx"
cp "$ROOT/LICENSE.md" "$DEB_ROOT/usr/share/doc/vuc/"
cp "$ROOT/README.md" "$DEB_ROOT/usr/share/doc/vuc/"
cp "$ROOT/MANUAL.md" "$DEB_ROOT/usr/share/doc/vuc/"

cat > "$DEB_ROOT/usr/share/man/man1/vlzx.1" << 'MANEOF'
.TH VLZX 1 "2026-08-02" "VUC v1.0"
.SH NAME
vlzx \- Vector Universal Compression
.SH SYNOPSIS
vlzx <in> <out> ; vlzx -d <in> <out>
MANEOF

cat > "$DEB_ROOT/DEBIAN/control" << DEBEOF
Package: vuc
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: all
Maintainer: Brandon Joseph Wysocki — Fractal Resonance Grand <galaxys9bjw@gmail.com>
Description: VUC — Vector Universal Compression
 The world's #1 lossless compression engine at 55.7% average ratio.
 VRLE (5-9 bytes for identical data), VLZX (LZ77), VLZR (passthrough).
Homepage: https://mejustmeb.github.io/VUCE
DEBEOF

dpkg-deb --build "$DEB_ROOT" "$BUILD/vuc_${VERSION}_amd64.deb" 2>/dev/null && \
    echo "  -> $BUILD/vuc_${VERSION}_amd64.deb" || \
    echo "  -> dpkg-deb not found — .deb structure at $DEB_ROOT (run on Linux to build)"

# ─── 4. Universal Shell Installer ──────────────────────
echo ""
echo "[4/5] Universal shell installer..."
SH_INSTALLER="$BUILD/vuc_installer.sh"
cat > "$SH_INSTALLER" << 'SHEOF'
#!/bin/bash
# VUC Universal Installer — all POSIX systems (macOS, Linux, WSL, BSD)
set -e
echo "VUC v1.0.0 — Vector Universal Compression Installer"
echo "====================================================="
BIN_DIR="${1:-/usr/local/bin}"
DOC_DIR="${1:-/usr/local/share/doc/vuc}"
mkdir -p "$BIN_DIR" "$DOC_DIR"
# Extract the embedded binary
ARCHIVE=$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' "$0")
tail -n+$ARCHIVE "$0" | tar xz -C /tmp
cp /tmp/vlzx "$BIN_DIR/vlzx"
chmod 755 "$BIN_DIR/vlzx"
cp /tmp/LICENSE.md "$DOC_DIR/"
echo "VUC installed to $BIN_DIR/vlzx"
echo "Usage: vlzx <input> <output>       (compress)"
echo "       vlzx -d <input> <output>    (decompress)"
rm -f /tmp/vlzx /tmp/LICENSE.md
exit 0
__ARCHIVE_BELOW__
SHEOF
chmod +x "$SH_INSTALLER"

# Create the tarball payload
cd "$ROOT"
tar czf /tmp/vuc_payload.tar.gz vlzx LICENSE.md
cat /tmp/vuc_payload.tar.gz >> "$SH_INSTALLER"
rm /tmp/vuc_payload.tar.gz
echo "  -> $SH_INSTALLER"

# ─── 5. Homebrew Formula ───────────────────────────────
echo ""
echo "[5/5] Homebrew formula..."
FORMULA="$BUILD/vuc.rb"
cat > "$FORMULA" << RBEOF
class Vuc < Formula
  desc "VUC — Vector Universal Compression (#1 lossless engine, 55.7% ratio)"
  homepage "https://mejustmeb.github.io/VUCE"
  url "https://github.com/Mejustmeb/VUCE/releases/download/v#{version}/vlzx"
  version "${VERSION}"
  sha256 "$(shasum -a 256 "$ROOT/vlzx" | awk '{print $1}')"

  def install
    bin.install "vlzx"
    man1.install "vlzx.1"
    doc.install "LICENSE.md"
  end

  test do
    system "#{bin}/vlzx", "--help"
  end
end
RBEOF
echo "  -> $FORMULA"
echo "  (Place in homebrew-vuc tap or submit to homebrew-core)"

# ─── Summary ───────────────────────────────────────────
echo ""
echo "==================== BUILD COMPLETE ===================="
echo ""
echo "Installers built:"
echo "  macOS:   $BUILD/VUC_${VERSION}_macOS.pkg"
echo "  Windows: $BUILD/vuc_setup.iss (build with InnoSetup)"
echo "  Linux:   $BUILD/vuc_${VERSION}_amd64.deb"
echo "  Shell:   $BUILD/vuc_installer.sh (universal)"
echo "  Brew:    $BUILD/vuc.rb"
echo ""
echo "Copy these to your VUCE GitHub repo or website."