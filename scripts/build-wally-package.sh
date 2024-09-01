#!/bin/sh

set -e

OUTPUT=$1

rm -rf temp
mkdir -p temp

cp -r src temp/src
rm -rf $OUTPUT

mkdir -p $OUTPUT
cp LICENSE $OUTPUT/LICENSE

node ./scripts/npm-to-wally.js package.json $OUTPUT/wally.toml $OUTPUT/default.project.json temp/wally-package.project.json

cp .darklua-roblox.json temp

rojo sourcemap temp/wally-package.project.json --output temp/sourcemap.json

darklua process --config temp/.darklua-roblox.json temp/src $OUTPUT/src

rm -rf temp

wally package --project-path $OUTPUT --list