(* camlp4r q_MLast.cmo *)
(* $Id: prtools.ml,v 1.1 2007/07/11 09:46:18 deraugla Exp $ *)
(* Copyright (c) INRIA 2007 *)

open Pretty;
open Pcaml.Printers;

type pr_gfun 'a 'b = pr_context string 'b -> 'a -> string;

value tab ind = String.make ind ' ';

(* horizontal list *)
value rec hlist elem pc xl =
  match xl with
  [ [] -> sprintf "%s%s" pc.bef pc.aft
  | [x] -> elem pc x
  | [x :: xl] ->
      sprintf "%s %s" (elem {(pc) with aft = ""; dang = ""} x)
        (hlist elem {(pc) with bef = ""} xl) ]
;

(* horizontal list with different function from 2nd element on *)
value rec hlist2 elem elem2 ({aft = (k0, k)} as pc) xl =
  match xl with
  [ [] -> invalid_arg "hlist2"
  | [x] -> elem {(pc) with aft = k} x
  | [x :: xl] ->
      sprintf "%s %s" (elem {(pc) with aft = k0} x)
        (hlist2 elem2 elem2 {(pc) with bef = ""} xl) ]
;

(* horizontal list with different function for the last element *)
value rec hlistl elem eleml pc xl =
  match xl with
  [ [] -> sprintf "%s%s" pc.bef pc.aft
  | [x] -> eleml pc x
  | [x :: xl] ->
      sprintf "%s %s" (elem {(pc) with aft = ""; dang = ""} x)
        (hlistl elem eleml {(pc) with bef = ""} xl) ]
;

(* vertical list *)
value rec vlist elem pc xl =
  match xl with
  [ [] -> sprintf "%s%s" pc.bef pc.aft
  | [x] -> elem pc x
  | [x :: xl] ->
      sprintf "%s\n%s" (elem {(pc) with aft = ""; dang = ""} x)
        (vlist elem {(pc) with bef = tab pc.ind} xl) ]
;

(* vertical list with different function from 2nd element on *)
value rec vlist2 elem elem2 ({aft = (k0, k)} as pc) xl =
  match xl with
  [ [] -> invalid_arg "vlist2"
  | [x] -> elem {(pc) with aft = k} x
  | [x :: xl] ->
      sprintf "%s\n%s" (elem {(pc) with aft = k0} x)
        (vlist2 elem2 elem2 {(pc) with bef = tab pc.ind} xl) ]
;

(* vertical list with different function for the last element *)
value rec vlistl elem eleml pc xl =
  match xl with
  [ [] -> sprintf "%s%s" pc.bef pc.aft
  | [x] -> eleml pc x
  | [x :: xl] ->
      sprintf "%s\n%s" (elem {(pc) with aft = ""; dang = ""} x)
        (vlistl elem eleml {(pc) with bef = tab pc.ind} xl) ]
;

value rise_string ind sh b s =
  (* hack for "plistl" (below): if s is a "string" (i.e. starting with
     double-quote) which contains newlines, attempt to concat its first
     line in the previous line, and, instead of displaying this:
              eprintf
                "\
           hello, world"
     displays that:
              eprintf "\
           hello, world"
     what "saves" one line.
   *)
  if String.length s > ind + sh && s.[ind+sh] = '"' then
    match try Some (String.index s '\n') with [ Not_found -> None ] with
    [ Some i ->
        let t = String.sub s (ind + sh) (String.length s - ind - sh) in
        let i = i - ind - sh in
        match
          horiz_vertic (fun () -> Some (sprintf "%s %s" b (String.sub t 0 i)))
            (fun () -> None)
        with
        [ Some b -> (b, String.sub t (i + 1) (String.length t - i - 1))
        | None -> (b, s) ]
    | None -> (b, s) ]
  else (b, s)
;

(* paragraph list with a different function for the last element;
   the list elements are pairs where second elements are separators
   (the last separator is ignored) *)
value rec plistl elem eleml sh pc xl =
  let (s1, s2o) = plistl_two_parts elem eleml sh pc xl in
  match s2o with
  [ Some s2 -> sprintf "%s\n%s" s1 s2
  | None -> s1 ]
and plistl_two_parts elem eleml sh pc xl =
  match xl with
  [ [] -> assert False
  | [(x, _)] -> (eleml pc x, None)
  | [(x, sep) :: xl] ->
      let s =
        horiz_vertic
          (fun () -> Some (elem {(pc) with aft = sep; dang = sep} x))
          (fun () -> None)
      in
      match s with
      [ Some b ->
          (plistl_kont_same_line elem eleml sh {(pc) with bef = b} xl, None)
      | None ->
          let s1 = elem {(pc) with aft = sep; dang = sep} x in
          let s2 =
            plistl elem eleml 0
              {(pc) with ind = pc.ind + sh; bef = tab (pc.ind + sh)} xl
          in
          (s1, Some s2) ] ]
and plistl_kont_same_line elem eleml sh pc xl =
  match xl with
  [ [] -> assert False
  | [(x, _)] ->
      horiz_vertic (fun () -> eleml {(pc) with bef = sprintf "%s " pc.bef} x)
        (fun () ->
           let s =
             eleml {(pc) with ind = pc.ind + sh; bef = tab (pc.ind + sh)} x
           in
           let (b, s) = rise_string pc.ind sh pc.bef s in
           sprintf "%s\n%s" b s)
  | [(x, sep) :: xl] ->
      let s =
        horiz_vertic
          (fun () ->
             Some
               (elem
                  {(pc) with bef = sprintf "%s " pc.bef; aft = sep;
                   dang = sep}
                  x))
          (fun () -> None)
      in
      match s with
      [ Some b -> plistl_kont_same_line elem eleml sh {(pc) with bef = b} xl
      | None ->
          let (s1, s2o) =
            plistl_two_parts elem eleml 0
              {(pc) with ind = pc.ind + sh; bef = tab (pc.ind + sh)}
              [(x, sep) :: xl]
          in
          match s2o with
          [ Some s2 ->
              let (b, s1) = rise_string pc.ind sh pc.bef s1 in
              sprintf "%s\n%s\n%s" b s1 s2
          | None -> sprintf "%s\n%s" pc.bef s1 ] ] ]
;

(* paragraph list *)
value plist elem sh pc xl = plistl elem elem sh pc xl;

(* paragraph list where the [pc.bef] is part of the algorithm, i.e. if the
   first element does not fit, there is a newline after the [pc.bef].*)
value plistb elem sh pc xl =
  match xl with
  [ [] -> sprintf "%s%s" pc.bef pc.aft
  | [(x, _)] ->
      horiz_vertic (fun () -> elem {(pc) with bef = sprintf "%s " pc.bef} x)
        (fun () ->
           let s =
             elem {(pc) with ind = pc.ind + sh; bef = tab (pc.ind + sh)} x
           in
           sprintf "%s\n%s" pc.bef s)
  | [(x, sep) :: xl] ->
      let s =
        horiz_vertic
          (fun () -> Some (elem {(pc) with aft = sep; dang = sep} x))
          (fun () -> None)
      in
      match s with
      [ Some b -> plistl_kont_same_line elem elem sh {(pc) with bef = b} xl
      | None ->
          let s1 =
            horiz_vertic (fun () -> elem {(pc) with aft = sep; dang = sep} x)
              (fun () ->
                 let s =
                   elem
                     {ind = pc.ind + sh; bef = tab (pc.ind + sh); aft = sep;
                      dang = sep}
                     x
                 in
                 sprintf "%s\n%s" pc.bef s)
          in
          let s2 =
            plistl elem elem 0
              {(pc) with ind = pc.ind + sh; bef = tab (pc.ind + sh)} xl
          in
          sprintf "%s\n%s" s1 s2 ] ]
;

(* comments *)

module Buff =
  struct
    value buff = ref (String.create 80);
    value store len x = do {
      if len >= String.length buff.val then
        buff.val := buff.val ^ String.create (String.length buff.val)
      else ();
      buff.val.[len] := x;
      succ len
    };
    value mstore len s =
      add_rec len 0 where rec add_rec len i =
        if i == String.length s then len
        else add_rec (store len s.[i]) (succ i)
    ;
    value get len = String.sub buff.val 0 len;
  end
;

value rev_extract_comment strm =
  let rec find_comm len =
    parser
    [ [: `' '; a = find_comm (Buff.store len ' ') ! :] -> a
    | [: `'\t'; a = find_comm (Buff.mstore len (String.make 8 ' ')) ! :] -> a
    | [: `'\n'; a = find_comm (Buff.store len '\n') ! :] -> a
    | [: `')'; a = find_star_bef_rparen (Buff.store len ')') ! :] -> a
    | [: :] -> 0 ]
  and find_star_bef_rparen len =
    parser
    [ [: `'*'; a = insert (Buff.store len '*') ! :] -> a
    | [: :] -> 0 ]
  and insert len =
    parser
    [ [: `')'; a = find_star_bef_rparen_in_comm (Buff.store len ')') ! :] -> a
    | [: `'*'; a = find_lparen_aft_star (Buff.store len '*') ! :] -> a
    | [: `'"'; a = insert_string (Buff.store len '"') ! :] -> a
    | [: `x; a = insert (Buff.store len x) ! :] -> a
    | [: :] -> len ]
  and insert_string len =
    parser
    [ [: `'"'; a = insert (Buff.store len '"') ! :] -> a
    | [: `x; a = insert_string (Buff.store len x) ! :] -> a
    | [: :] -> len ]
  and find_star_bef_rparen_in_comm len =
    parser
    [ [: `'*'; len = insert (Buff.store len '*'); a = insert len ! :] -> a
    | [: a = insert len :] -> a ]
  and find_lparen_aft_star len =
    parser
    [ [: `'('; a = while_space (Buff.store len '(') :] -> a
    | [: a = insert len :] -> a ]
  and while_space len =
    parser
    [ [: `' '; a = while_space (Buff.store len ' ') ! :] -> a
    | [: `'\t'; a = while_space (Buff.mstore len (String.make 8 ' ')) :] -> a
    | [: `'\n'; a = while_space (Buff.store len '\n') ! :] -> a
    | [: `')'; a = find_star_bef_rparen_again len ! :] -> a
    | [: :] -> len ]
  and find_star_bef_rparen_again len =
    parser
    [ [: `'*'; a = insert (Buff.mstore len ")*") ! :] -> a
    | [: :] -> len ]
  in
  let len = find_comm 0 strm in
  let s = Buff.get len in
  loop (len - 1) 0 0 where rec loop i nl_bef ind_bef =
    if i <= 0 then ("", 0, 0)
    else if s.[i] = '\n' then loop (i - 1) (nl_bef + 1) ind_bef
    else if s.[i] = ' ' then loop (i - 1) nl_bef (ind_bef + 1)
    else do {
      let s = String.sub s 0 (i + 1) in
      for i = 0 to String.length s / 2 - 1 do {
        let t = s.[i] in
        s.[i] := s.[String.length s - i - 1];
        s.[String.length s - i - 1] := t;
      };
      (s, nl_bef, ind_bef)
    }
;

value source = ref "";
value comm_min_pos = ref 0;

value set_comm_min_pos bp = comm_min_pos.val := bp;

value rev_read_comment_in_file bp ep =
  let strm =
    Stream.from
      (fun i ->
         let j = bp - i - 1 in
         if j < comm_min_pos.val || j >= String.length source.val then None
         else Some source.val.[j])
  in
  let (s, nl_bef, ind_bef) = rev_extract_comment strm in
  if s = "" then
    (* heuristic to find the possible comment before 'begin' or left
       parenthesis *)
    loop 0 where rec loop i =
      match strm with parser
      [ [: `'(' when i = 0 :] -> rev_extract_comment strm
      | [: `c when c = "begin".[4-i] :] ->
          if i = String.length "begin" - 1 then rev_extract_comment strm
          else loop (i + 1)
      | [: :] -> (s, nl_bef, ind_bef) ]
  else (s, nl_bef, ind_bef)
;

value adjust_comment_indentation ind s nl_bef ind_bef =
  if s = "" then ""
  else
    let (ind_aft, i_bef_ind) =
      loop 0 (String.length s - 1) where rec loop ind_aft i =
        if i >= 0 && s.[i] = ' ' then loop (ind_aft + 1) (i - 1)
        else (ind_aft, i)
    in
    let ind_bef = if nl_bef > 0 then ind_bef else ind in
    let len = i_bef_ind + 1 in
    let olen = Buff.mstore 0 (String.make ind ' ') in
    loop olen 0 where rec loop olen i =
      if i = len then Buff.get olen
      else
        let olen = Buff.store olen s.[i] in
        let (olen, i) =
          if s.[i] = '\n' && (i + 1 = len || s.[i+1] <> '\n') then
            let delta_ind = if i = i_bef_ind then 0 else ind - ind_bef in
            if delta_ind >= 0 then
              (Buff.mstore olen (String.make delta_ind ' '), i + 1)
            else
              let i =
                loop delta_ind (i + 1) where rec loop cnt i =
                  if cnt = 0 then i
                  else if i = len then i
                  else if s.[i] = ' ' then loop (cnt + 1) (i + 1)
                  else i
              in
              (olen, i)
          else (olen, i + 1)
        in
        loop olen i
;

value comm_bef ind loc =
  let ind = ind.ind in
  let bp = Stdpp.first_pos loc in
  let ep = Stdpp.last_pos loc in
  let (s, nl_bef, ind_bef) = rev_read_comment_in_file bp ep in
  adjust_comment_indentation ind s nl_bef ind_bef
;

(* For pretty printing improvement:
   - if e is a "sequence" or a "let..in sequence", get "the list of its
     expressions", which is flattened (merging sequences inside sequences
     and changing "let..in do {e1; .. en}" into "do {let..in e1; .. en}",
     and return Some "the resulting expression list".
   - otherwise return None *)
value flatten_sequence e =
  let rec get_sequence =
    fun
    [ <:expr< do { $list:el$ } >> -> Some el
    | <:expr< let $opt:rf$ $list:pel$ in $e$ >> as se ->
        match get_sequence e with
        [ Some [e :: el] ->
            let e =
              let loc =
                let loc1 = MLast.loc_of_expr se in
                let loc2 = MLast.loc_of_expr e in
                Stdpp.encl_loc loc1 loc2
              in
              <:expr< let $opt:rf$ $list:pel$ in $e$ >>
            in
            Some [e :: el]
        | None | _ -> None ]
    | _ -> None ]
  in
  match get_sequence e with
  [ Some el ->
      let rec list_of_sequence =
        fun
        [ [e :: el] ->
            match get_sequence e with
            [ Some el1 -> list_of_sequence (el1 @ el)
            | None -> [e :: list_of_sequence el] ]
        | [] -> [] ]
      in
      Some (list_of_sequence el)
  | None -> None ]
;