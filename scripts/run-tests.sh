#!/bin/sh

set -e

if [ ! -f temp/tests.json ]; then
	scripts/generate-tests.sh
fi

lune run test/runner
