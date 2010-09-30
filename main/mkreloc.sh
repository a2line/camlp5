#!/bin/sh
# $Id: mkreloc.sh,v 6.2 2010/09/30 14:25:52 deraugla Exp $

IFILE=pa_r.ml
OFILE=reloc.ml
(
sed -e '/^value rec ctyp/,$d' $OFILE
echo "value rec ctyp floc sh ="
ocamlrun ../meta/camlp5r -nolib -I ../meta -I ../etc pa_reloc.cmo pr_r.cmo -impl mLast.mli |
sed -e '/| ..Xtr/{N; N; s/\n */@/g}' |
sed -e 's/| \(..Xtr.*\) ]$/| IFDEF STRICT THEN\n        \1\n      END ]/' |
sed -e 's/@/\n          /g' |
sed -e '1,/value rec ctyp/d;/external/,$d'
echo '(* Equality over syntax trees *)'
sed -e '1,/Equality over syntax trees/d' $OFILE
)
