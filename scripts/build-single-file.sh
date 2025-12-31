#!/bin/sh

set -e

darklua process --config .darklua-bundle.json src/init.luau build/png.luau
stylua build/png.luau
