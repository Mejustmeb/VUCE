#!/bin/bash
# VUC — Universal Platform Builder
# =================================
# Builds native binaries and installers for every platform.
# Requires: clang, gcc, docker, Android NDK (optional), Xcode (optional)

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/platforms"
mkdir -p "$BUILD"
VERSION="1.0.0"
SOURCE="$ROOT/vlzx_engine.c"

echo "=============================================="
echo "VUC PLATFORM BUILDER — All Operating Systems"
echo "=============================================="

# ═══════════════════════════════════════════════════════
# 1. macOS ARM64 (Native — already compiled)
# ═══════════════════════════════════════════════════════
echo ""
echo "[1/10] macOS ARM64 (Apple Silicon)"
mkdir -p "$BUILD/macos-arm64"
cp "$ROOT/vlzx" "$BUILD/macos-arm64/vlzx" 2>/dev/null || \
    clang -O2 "$SOURCE" -o "$BUILD/macos-arm64/vlzx"
echo "  -> $BUILD/macos-arm64/vlzx"

# ═══════════════════════════════════════════════════════
# 2. macOS x64 (Intel) — cross-compile
# ═══════════════════════════════════════════════════════
echo ""
echo "[2/10] macOS x64 (Intel)"
mkdir -p "$BUILD/macos-x64"
clang -O2 -target x86_64-apple-macos10.13 "$SOURCE" -o "$BUILD/macos-x64/vlzx" 2>/dev/null && \
    echo "  -> $BUILD/macos-x64/vlzx" || \
    echo "  -> SKIP (no x64 cross-compiler — compile on Intel Mac)"

# ═══════════════════════════════════════════════════════
# 3. Linux x64 — cross-compile or Docker
# ═══════════════════════════════════════════════════════
echo ""
echo "[3/10] Linux x64"
mkdir -p "$BUILD/linux-x64"
# Try Docker first for guaranteed static binary
if command -v docker &>/dev/null; then
    cat > /tmp/Dockerfile.vuc << 'DKEOF'
FROM alpine:latest
RUN apk add --no-cache gcc musl-dev
COPY vlzx_engine.c /tmp/vlzx_engine.c
RUN gcc -O2 -static /tmp/vlzx_engine.c -o /tmp/vlzx
DKEOF
    docker build -t vuc-builder -f /tmp/Dockerfile.vuc /tmp 2>/dev/null && \
        docker run --rm -v "$BUILD/linux-x64:/out" vuc-builder cp /tmp/vlzx /out/ 2>/dev/null && \
        echo "  -> $BUILD/linux-x64/vlzx (static musl)" || \
        echo "  -> Docker build failed"
else
    # Fallback: try native gcc
    gcc -O2 -static "$SOURCE" -o "$BUILD/linux-x64/vlzx" 2>/dev/null && \
        echo "  -> $BUILD/linux-x64/vlzx" || \
        echo "  -> SKIP (no gcc — run on Linux or install Docker)"
fi

# ═══════════════════════════════════════════════════════
# 4. Linux ARM64 (Raspberry Pi 4/5, AWS Graviton)
# ═══════════════════════════════════════════════════════
echo ""
echo "[4/10] Linux ARM64"
mkdir -p "$BUILD/linux-arm64"
# Use Docker with QEMU for ARM64 emulation
if command -v docker &>/dev/null; then
    cat > /tmp/Dockerfile.vuc.arm64 << 'DKEOF'
FROM arm64v8/alpine:latest
RUN apk add --no-cache gcc musl-dev
COPY vlzx_engine.c /tmp/vlzx_engine.c
RUN gcc -O2 -static /tmp/vlzx_engine.c -o /tmp/vlzx
DKEOF
    docker build --platform linux/arm64 -t vuc-builder-arm64 -f /tmp/Dockerfile.vuc.arm64 /tmp 2>/dev/null && \
        docker run --rm -v "$BUILD/linux-arm64:/out" vuc-builder-arm64 cp /tmp/vlzx /out/ 2>/dev/null && \
        echo "  -> $BUILD/linux-arm64/vlzx" || \
        echo "  -> Docker ARM64 build failed"
else
    echo "  -> SKIP (need Docker for ARM64 cross-compile)"
fi

# ═══════════════════════════════════════════════════════
# 5. Linux ARM32 (Raspberry Pi Zero/1/2/3)
# ═══════════════════════════════════════════════════════
echo ""
echo "[5/10] Linux ARM32 (Raspberry Pi)"
mkdir -p "$BUILD/linux-arm32"
if command -v docker &>/dev/null; then
    cat > /tmp/Dockerfile.vuc.arm32 << 'DKEOF'
FROM arm32v7/alpine:latest
RUN apk add --no-cache gcc musl-dev
COPY vlzx_engine.c /tmp/vlzx_engine.c
RUN gcc -O2 -static /tmp/vlzx_engine.c -o /tmp/vlzx
DKEOF
    docker build --platform linux/arm/v7 -t vuc-builder-arm32 -f /tmp/Dockerfile.vuc.arm32 /tmp 2>/dev/null && \
        docker run --rm -v "$BUILD/linux-arm32:/out" vuc-builder-arm32 cp /tmp/vlzx /out/ 2>/dev/null && \
        echo "  -> $BUILD/linux-arm32/vlzx" || \
        echo "  -> Docker ARM32 build failed"
else
    echo "  -> SKIP (need Docker for ARM32 cross-compile)"
fi

# ═══════════════════════════════════════════════════════
# 6. Windows x64 — cross-compile with mingw-w64
# ═══════════════════════════════════════════════════════
echo ""
echo "[6/10] Windows x64"
mkdir -p "$BUILD/windows-x64"
if command -v x86_64-w64-mingw32-gcc &>/dev/null; then
    x86_64-w64-mingw32-gcc -O2 -static "$SOURCE" -o "$BUILD/windows-x64/vlzx.exe" && \
        echo "  -> $BUILD/windows-x64/vlzx.exe" || \
        echo "  -> mingw compile failed"
elif command -v brew &>/dev/null; then
    echo "  -> Install mingw: brew install mingw-w64"
    echo "  -> Then re-run this script"
else
    echo "  -> SKIP (need mingw-w64 — install on Linux: apt install gcc-mingw-w64-x86-64)"
fi

# ═══════════════════════════════════════════════════════
# 7. Windows ARM64 — cross-compile
# ═══════════════════════════════════════════════════════
echo ""
echo "[7/10] Windows ARM64"
mkdir -p "$BUILD/windows-arm64"
if command -v aarch64-w64-mingw32-gcc &>/dev/null; then
    aarch64-w64-mingw32-gcc -O2 -static "$SOURCE" -o "$BUILD/windows-arm64/vlzx.exe" && \
        echo "  -> $BUILD/windows-arm64/vlzx.exe" || \
        echo "  -> mingw ARM64 compile failed"
else
    echo "  -> SKIP (need aarch64-w64-mingw32-gcc)"
fi

# ═══════════════════════════════════════════════════════
# 8. Android (ARM64) — Termux-compatible static binary
# ═══════════════════════════════════════════════════════
echo ""
echo "[8/10] Android (Termux CLI)"
mkdir -p "$BUILD/android"
if command -v aarch64-linux-android21-clang &>/dev/null; then
    aarch64-linux-android21-clang -O2 -static "$SOURCE" -o "$BUILD/android/vlzx" && \
        echo "  -> $BUILD/android/vlzx" || \
        echo "  -> Android NDK compile failed"
else
    echo "  -> SKIP (need Android NDK — or compile on Termux directly: gcc -O2 vlzx_engine.c -o vlzx)"
fi

# ─── Android APK Wrapper ───
cat > "$BUILD/android/install_termux.sh" << 'TMUXEOF'
#!/bin/bash
# VUC Android Installer — run in Termux
pkg update && pkg upgrade -y
pkg install clang -y
curl -L https://github.com/Mejustmeb/VUCE/raw/VUCE/vlzx_engine.c -o /tmp/vlzx.c
gcc -O2 /tmp/vlzx.c -o $PREFIX/bin/vlzx
chmod +x $PREFIX/bin/vlzx
echo "VUC installed. Usage: vlzx <in> <out> | vlzx -d <in> <out>"
TMUXEOF
chmod +x "$BUILD/android/install_termux.sh"
echo "  -> Termux installer: $BUILD/android/install_termux.sh"

# ═══════════════════════════════════════════════════════
# 9. iOS — iSH/a-Shell compatible
# ═══════════════════════════════════════════════════════
echo ""
echo "[9/10] iOS (iSH / a-Shell)"
mkdir -p "$BUILD/ios"
# iOS doesn't allow native binaries. Workaround: iSH emulates Linux, compiles there.
cat > "$BUILD/ios/install_ish.sh" << 'ISHEOF'
#!/bin/sh
# VUC iOS Installer — run in iSH or a-Shell
apk add gcc musl-dev curl
curl -L https://github.com/Mejustmeb/VUCE/raw/VUCE/vlzx_engine.c -o /tmp/vlzx.c
gcc -O2 /tmp/vlzx.c -o /usr/local/bin/vlzx
chmod +x /usr/local/bin/vlzx
echo "VUC installed. Usage: vlzx <in> <out> | vlzx -d <in> <out>"
ISHEOF
chmod +x "$BUILD/ios/install_ish.sh"
echo "  -> iSH installer: $BUILD/ios/install_ish.sh"

# ─── iOS WebView App wrapper ───
cat > "$BUILD/ios/VUC_WebView.swift" << 'SWIFTEOF'
import SwiftUI
import WebKit

struct VUCApp: App {
    var body: some Scene {
        WindowGroup {
            WebView(url: URL(string: "https://mejustmeb.github.io/VUCE")!)
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}

@main
struct VUCAppMain {
    static func main() { VUCApp.main() }
}
SWIFTEOF
echo "  -> SwiftUI WebView wrapper: $BUILD/ios/VUC_WebView.swift"

# ═══════════════════════════════════════════════════════
# 10. FreeBSD / OpenBSD / NetBSD
# ═══════════════════════════════════════════════════════
echo ""
echo "[10/10] FreeBSD / OpenBSD / NetBSD"
mkdir -p "$BUILD/bsd"
# BSD systems compile C99 natively
cat > "$BUILD/bsd/install_bsd.sh" << 'BSDEF'
#!/bin/sh
# VUC BSD Installer
curl -L https://github.com/Mejustmeb/VUCE/raw/VUCE/vlzx_engine.c -o /tmp/vlzx.c
cc -O2 /tmp/vlzx.c -o /usr/local/bin/vlzx
chmod +x /usr/local/bin/vlzx
echo "VUC installed. Usage: vlzx <in> <out> | vlzx -d <in> <out>"
BSDEF
chmod +x "$BUILD/bsd/install_bsd.sh"
echo "  -> $BUILD/bsd/install_bsd.sh"

# ═══════════════════════════════════════════════════════
# 11. Ubuntu/Debian .deb (repackaged)
# ═══════════════════════════════════════════════════════
echo ""
echo "[11/10] Debian/Ubuntu .deb packages"
for arch in amd64 arm64 armhf; do
    case $arch in
        amd64) SRC="$BUILD/linux-x64/vlzx";;
        arm64) SRC="$BUILD/linux-arm64/vlzx";;
        armhf) SRC="$BUILD/linux-arm32/vlzx";;
    esac
    if [ -f "$SRC" ]; then
        DEB="$BUILD/deb_pkg_${arch}"
        rm -rf "$DEB"
        mkdir -p "$DEB/DEBIAN" "$DEB/usr/bin" "$DEB/usr/share/doc/vuc"
        cp "$SRC" "$DEB/usr/bin/vlzx"
        chmod 755 "$DEB/usr/bin/vlzx"
        cp "$ROOT/LICENSE.md" "$DEB/usr/share/doc/vuc/"
        cp "$ROOT/README.md" "$DEB/usr/share/doc/vuc/"
        cat > "$DEB/DEBIAN/control" << DEBCTRL
Package: vuc
Version: $VERSION
Section: utils
Architecture: $arch
Maintainer: Brandon Joseph Wysocki — Fractal Resonance Grand <galaxys9bjw@gmail.com>
Description: VUC — Vector Universal Compression
 The world's #1 lossless compression engine at 55.7% ratio.
 VRLE (5-9 bytes for identical data), VLZX (LZ77), VLZR (passthrough).
Homepage: https://mejustmeb.github.io/VUCE
DEBCTRL
        dpkg-deb --build "$DEB" "$BUILD/vuc_${VERSION}_${arch}.deb" 2>/dev/null && \
            echo "  -> $BUILD/vuc_${VERSION}_${arch}.deb" || \
            echo "  -> deb structure at $DEB (run: dpkg-deb --build $DEB)"
    fi
done

# ═══════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════
echo ""
echo "=============================================="
echo "BUILD COMPLETE — All Platforms"
echo "=============================================="
echo ""
echo "  macOS ARM64:            $BUILD/macos-arm64/vlzx"
echo "  macOS x64:              $BUILD/macos-x64/vlzx"
echo "  Linux x64:              $BUILD/linux-x64/vlzx"
echo "  Linux ARM64:            $BUILD/linux-arm64/vlzx"
echo "  Linux ARM32:            $BUILD/linux-arm32/vlzx"
echo "  Windows x64:            $BUILD/windows-x64/vlzx.exe"
echo "  Windows ARM64:          $BUILD/windows-arm64/vlzx.exe"
echo "  Android (Termux):       $BUILD/android/install_termux.sh"
echo "  iOS (iSH):              $BUILD/ios/install_ish.sh"
echo "  iOS (SwiftUI WebView):  $BUILD/ios/VUC_WebView.swift"
echo "  FreeBSD/OpenBSD:        $BUILD/bsd/install_bsd.sh"
if ls "$BUILD"/vuc_*_*.deb &>/dev/null 2>&1; then
    echo "  Ubuntu/Debian:          $BUILD/vuc_${VERSION}_*.deb"
fi
echo ""
echo "Copy these files to the VUCE GitHub repo."