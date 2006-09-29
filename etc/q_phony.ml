(* camlp4r pa_extend.cmo q_MLast.cmo *)
(***********************************************************************)
(*                                                                     *)
(*                             Camlp4                                  *)
(*                                                                     *)
(*        Daniel de Rauglaudre, projet Cristal, INRIA Rocquencourt     *)
(*                                                                     *)
(*  Copyright 2002 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)

(* $Id: q_phony.ml,v 1.1 2006/09/29 04:45:49 deraugla Exp $ *)

open Pcaml;

value t = ref "";

Quotation.add ""
  (Quotation.ExAst
     (fun s ->
        let t =
          if t.val = "" then "<<" ^ s ^ ">>"
          else "<:" ^ t.val ^ "<" ^ s ^ ">>"
        in
        let loc = (0, 0) in
        <:expr< $uid:t$ >>,
      fun s ->
        let t =
          if t.val = "" then "<<" ^ s ^ ">>"
          else "<:" ^ t.val ^ "<" ^ s ^ ">>"
        in
        let loc = (0, 0) in
        <:patt< $uid:t$ >>))
;

Quotation.default.val := "";
Quotation.translate.val := fun s -> do { t.val := s; "" };

if Pcaml.syntax_name.val <> "Scheme" then
  EXTEND
    expr: LEVEL "top"
      [ [ "IFDEF"; c = UIDENT; "THEN"; e1 = expr; "ELSE"; e2 = expr; "END" ->
            <:expr< if DEF $uid:c$ then $e1$ else $e2$ >>
        | "IFNDEF"; c = UIDENT; "THEN"; e1 = expr; "ELSE"; e2 = expr; "END" ->
            <:expr< if NDEF $uid:c$ then $e1$ else $e2$ >> ] ]
    ;
  END
else ();
