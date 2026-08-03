#!/bin/sh
# VUC BSD Installer
curl -L https://github.com/Mejustmeb/VUCE/raw/VUCE/vlzx_engine.c -o /tmp/vlzx.c
cc -O2 /tmp/vlzx.c -o /usr/local/bin/vlzx
chmod +x /usr/local/bin/vlzx
echo "VUC installed. Usage: vlzx <in> <out> | vlzx -d <in> <out>"
