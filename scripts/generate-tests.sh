#!/bin/sh

set -e

rm -rf temp
mkdir temp

node test/generate-tests.js