#!/bin/sh

set -e

OUTPUT=$1

rm -rf temp
mkdir -p temp
cp -r src/ temp/

rm -f $OUTPUT
mkdir -p $(dirname $OUTPUT)

darklua process --config .darklua-bundle.json temp/src/init.luau $OUTPUT

TEMP=$(mktemp)
echo "--!native" > $TEMP
echo "--!optimize 2" >> $TEMP
echo "--!nonstrict" >> $TEMP
echo "" >> $TEMP
cat $OUTPUT >> $TEMP
mv $TEMP $OUTPUT

stylua $OUTPUT

rm -rf temp
