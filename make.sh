#! /bin/sh
# Adapted from https://github.com/ProducerMatt/redbean-template
#
# Author : Dr Mark S. Brown
# Started : 27th Jan 2025
# License : MIT
#
IN_FILE="redbean-3.0.0.com"
OUT_FILE="explorer.com"

_Init() {
  chmod +x "zip.com"
}

_Pack () {
  cp -f $IN_FILE $OUT_FILE
  chmod u+w $OUT_FILE
  chmod +x $OUT_FILE

  cd srv/
    ../zip.com -r "../$OUT_FILE" `ls -A`
  cd ..
}

case "$1" in
  pack )
    _Pack;
    ;;
  * )
    echo "Simple makefile for packing redbean executable"
    echo "- '$0 pack': pack "./srv/" into a new redbean, overwriting the old"
    ;;
esac
