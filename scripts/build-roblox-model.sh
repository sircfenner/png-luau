#!/bin/sh

set -e

SOURCE=$1
OUTPUT=$2

if [ ! -d $SOURCE ]; then
	scripts/build-wally-package.sh
fi

rojo build $SOURCE/default.project.json -o $OUTPUT
