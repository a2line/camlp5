(* camlp5r *)
(* $Id: pa_extprint.ml,v 1.2 2007/08/15 10:57:10 deraugla Exp $ *)
(* Copyright (c) INRIA 2007 *)

#load "pa_extend.cmo";
#load "q_MLast.cmo";

open Pcaml;

type entry 'e 'p = { name : 'e; pos : option 'e; levels : list (level 'e 'p) }
and level 'e 'p = { label : option string; rules : list (rule 'e 'p) }
and rule 'e 'p = ('p * option 'e * 'e);

value not_impl name x = do {
  let desc =
    if Obj.is_block (Obj.repr x) then
      "tag = " ^ string_of_int (Obj.tag (Obj.repr x))
    else "int_val = " ^ string_of_int (Obj.magic x)
  in
  print_newline ();
  failwith ("pa_extprint: not impl " ^ name ^ " " ^ desc)
};

value rec mexpr p =
  let loc = MLast.loc_of_patt p in
  match p with
  [ <:patt< $p1$ $p2$ >> ->
      loop <:expr< [$mexpr p2$] >> p1 where rec loop el =
        fun
        [ <:patt< $p1$ $p2$ >> -> loop <:expr< [$mexpr p2$ :: $el$] >> p1
        | p -> <:expr< Extfun.Eapp [$mexpr p$ :: $el$] >> ]
  | <:patt< $p1$ . $p2$ >> ->
      loop <:expr< [$mexpr p2$] >> p1 where rec loop el =
        fun
        [ <:patt< $p1$ . $p2$ >> -> loop <:expr< [$mexpr p2$ :: $el$] >> p1
        | p -> <:expr< Extfun.Eacc [$mexpr p$ :: $el$] >> ]
  | <:patt< ($list:pl$) >> -> <:expr< Extfun.Etup $mexpr_list loc pl$ >>
  | <:patt< $uid:id$ >> -> <:expr< Extfun.Econ $str:id$ >>
  | <:patt< ` $id$ >> -> <:expr< Extfun.Econ $str:id$ >>
  | <:patt< $int:s$ >> -> <:expr< Extfun.Eint $str:s$ >>
  | <:patt< $str:s$ >> -> <:expr< Extfun.Estr $str:s$ >>
  | <:patt< ($p1$ as $_$) >> -> mexpr p1
  | <:patt< $lid:_$ >> -> <:expr< Extfun.Evar () >>
  | <:patt< _ >> -> <:expr< Extfun.Evar () >>
  | <:patt< $p1$ | $p2$ >> ->
      Stdpp.raise_with_loc loc (Failure "or patterns not allowed in extfun")
  | p -> not_impl "mexpr" p ]
and mexpr_list loc =
  fun
  [ [] -> <:expr< [] >>
  | [e :: el] -> <:expr< [$mexpr e$ :: $mexpr_list loc el$] >> ]
;

value rec split_or =
  fun
  [ [(<:patt< $p1$ | $p2$ >>, wo, e) :: pel] ->
      split_or [(p1, wo, e); (p2, wo, e) :: pel]
  | [(<:patt< ($p1$ | $p2$ as $p$) >>, wo, e) :: pel] ->
      let p1 =
        let loc = MLast.loc_of_patt p1 in
        <:patt< ($p1$ as $p$) >>
      in
      let p2 =
        let loc = MLast.loc_of_patt p2 in
        <:patt< ($p2$ as $p$) >>
      in
      split_or [(p1, wo, e); (p2, wo, e) :: pel]
  | [pe :: pel] -> [pe :: split_or pel]
  | [] -> [] ]
;

value rec catch_any =
  fun
  [ <:patt< $uid:id$ >> -> False
  | <:patt< ` $_$ >> -> False
  | <:patt< $lid:_$ >> -> True
  | <:patt< _ >> -> True
  | <:patt< ($list:pl$) >> -> List.for_all catch_any pl
  | <:patt< $p1$ $p2$ >> -> False
  | <:patt< $p1$ | $p2$ >> -> False
  | <:patt< $int:_$ >> -> False
  | <:patt< $str:_$ >> -> False
  | <:patt< ($p1$ as $_$) >> -> catch_any p1
  | p -> not_impl "catch_any" p ]
;

value conv loc (p, wo, e) =
  let tst = mexpr p in
  let e = <:expr< fun curr next pc -> $e$ >> in
  let e =
    if wo = None && catch_any p then <:expr< fun $p$ -> Some $e$ >>
    else <:expr< fun [ $p$ $opt:wo$ -> Some $e$ | _ -> None ] >>
  in
  <:expr< ($tst$, False, $e$) >>
;

value text_of_extprint loc el =
  let e =
    List.fold_right
      (fun e el ->
         let pos =
           match e.pos with
           [ Some e -> <:expr< Some $e$ >>
           | None -> <:expr< None >> ]
         in
         let levs =
           List.fold_right
             (fun lev levs ->
                let lab =
                  match lev.label with
                  [ Some s -> <:expr< Some $str:s$ >>
                  | None -> <:expr< None >> ]
                in
                let rules = split_or lev.rules in
                let rules =
                  rules @ [(<:patt< z >>, None, <:expr< next pc z >>)]
                in
                let rules =
                  List.fold_right
                    (fun pe rules ->
                       let rule = conv loc pe in
                       <:expr< [$rule$ :: $rules$] >>)
                    rules <:expr< [] >>
                in
                let rules = <:expr< fun e -> Extfun.extend e $rules$ >> in
                <:expr< [($lab$, $rules$) :: $levs$] >>)
             e.levels <:expr< [] >>
         in
         <:expr< [($e.name$, $pos$, $levs$) :: $el$] >>)
    el <:expr< [] >>
  in
  <:expr< extend_printer $e$ >>
;

EXTEND
  GLOBAL: expr;
  expr: AFTER "top"
    [ [ "EXTEND_PRINTER"; e = extprint_body; "END" -> e ] ]
  ;
  extprint_body:
    [ [ el = LIST1 [ e = entry; ";" -> e ] -> text_of_extprint loc el ] ]
  ;
  entry:
    [ [ n = name; ":"; pos = OPT position; ll = level_list ->
          {name = n; pos = pos; levels = ll} ] ]
  ;
  level_list:
    [ [ "["; ll = LIST0 level SEP "|"; "]" -> ll ] ]
  ;
  level:
    [ [ lab = OPT STRING; rules = rule_list ->
          {label = lab; rules = rules} ] ]
  ;
  rule_list:
    [ [ "["; "]" -> []
      | "["; rules = LIST1 rule SEP "|"; "]" -> rules ] ]
  ;
  rule:
    [ [ p = patt_as; "->"; e = expr -> (p, None, e) ] ]
  ;
  patt_as:
    [ [ p = patt -> p
      | p1 = patt; "as"; p2 = patt -> <:patt< ($p1$ as $p2$) >> ] ]
  ;
  position:
    [ [ UIDENT "FIRST" -> <:expr< Gramext.First >>
      | UIDENT "LAST" -> <:expr< Gramext.Last >>
      | UIDENT "BEFORE"; n = STRING -> <:expr< Gramext.Before $str:n$ >>
      | UIDENT "AFTER"; n = STRING -> <:expr< Gramext.After $str:n$ >>
      | UIDENT "LEVEL"; n = STRING -> <:expr< Gramext.Level $str:n$ >> ] ]
  ;
  name:
    [ [ e = qualid -> e ] ]
  ;
  qualid:
    [ [ e1 = SELF; "."; e2 = SELF -> <:expr< $e1$ . $e2$ >> ]
    | [ i = UIDENT -> <:expr< $uid:i$ >>
      | i = LIDENT -> <:expr< $lid:i$ >> ] ]
  ;
END;