#!/bin/sh
# VUC iOS Installer — run in iSH or a-Shell
apk add gcc musl-dev curl
curl -L https://github.com/Mejustmeb/VUCE/raw/VUCE/vlzx_engine.c -o /tmp/vlzx.c
gcc -O2 /tmp/vlzx.c -o /usr/local/bin/vlzx
chmod +x /usr/local/bin/vlzx
echo "VUC installed. Usage: vlzx <in> <out> | vlzx -d <in> <out>"
