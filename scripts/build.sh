#!/bin/sh

set -e

scripts/build-wally-package.sh build/wally
scripts/build-roblox-model.sh build/wally build/png.rbxm
scripts/build-single-file.sh build/png.luau
