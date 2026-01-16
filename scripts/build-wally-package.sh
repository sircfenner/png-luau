#!/bin/sh

set -e

OUT="build/wally"

mkdir $OUT
cp -r src $OUT/src
cp LICENSE $OUT/LICENSE
cp default.project.json $OUT/default.project.json
cp wally.toml $OUT/wally.toml

darklua process --config .darklua-strict.json $OUT $OUT
stylua $OUT
