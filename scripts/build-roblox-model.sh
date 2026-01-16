#!/bin/sh

set -e

TMP="build/roblox"

mkdir $TMP
cp -r src $TMP/src
cp default.project.json $TMP/default.project.json

darklua process --config .darklua-strict.json $TMP $TMP
stylua $TMP

rojo build $TMP/default.project.json -o build/png.rbxm

rm -rf $TMP
