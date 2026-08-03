#!/bin/bash
# VUC Android Installer — run in Termux
pkg update && pkg upgrade -y
pkg install clang -y
curl -L https://github.com/Mejustmeb/VUCE/raw/VUCE/vlzx_engine.c -o /tmp/vlzx.c
gcc -O2 /tmp/vlzx.c -o $PREFIX/bin/vlzx
chmod +x $PREFIX/bin/vlzx
echo "VUC installed. Usage: vlzx <in> <out> | vlzx -d <in> <out>"
