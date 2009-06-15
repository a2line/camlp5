#!/bin/sh
# $Id: mkcamlp5.sh.tpl,v 1.1 2007/07/11 12:01:39 deraugla Exp $

OLIB=`ocamlc -where`
LIB=LIBDIR/camlp5

INTERFACES=
OPTS=
INCL="-I ."
while test "" != "$1"; do
    case $1 in
    -I) INCL="$INCL -I $2"; shift;;
    *)
	j=`basename $1 .cmi`
	if test "$j.cmi" = "$1"; then
	    first="`expr "$j" : '\(.\)' | tr 'a-z' 'A-Z'`"
	    rest="`expr "$j" : '.\(.*\)'`"
	    INTERFACES="$INTERFACES $first$rest"
	else
	    OPTS="$OPTS $1"
	fi;;
    esac
    shift
done

CRC=crc_$$
set -e
trap 'rm -f $CRC.ml $CRC.cmi $CRC.cmo' 0 2
$OLIB/extract_crc -I $OLIB $INCL $INTERFACES > $CRC.ml
echo "let _ = Dynlink.add_available_units crc_unit_list" >> $CRC.ml
ocamlc -I $LIB odyl.cma camlp5.cma $CRC.ml $INCL $OPTS odyl.cmo -linkall
rm -f $CRC.ml $CRC.cmi $CRC.cmo