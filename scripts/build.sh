#!/bin/sh

set -e

rm -rf build
mkdir build

scripts/build-wally-package.sh
scripts/build-roblox-model.sh
scripts/build-single-file.sh
