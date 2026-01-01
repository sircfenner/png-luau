#!/bin/sh

set -e

TMP="build/roblox"

mkdir $TMP
cp -r src $TMP/src
cp model.project.json $TMP/model.project.json

darklua process --config .darklua-strict.json $TMP $TMP
stylua $TMP

rojo build $TMP/model.project.json -o build/png.rbxm

rm -rf $TMP
