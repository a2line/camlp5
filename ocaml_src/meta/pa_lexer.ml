(* camlp5r *)
(* pa_lexer.ml,v *)
(* Copyright (c) INRIA 2007-2016 *)

(* #load "pa_extend.cmo" *)
(* #load "q_MLast.cmo" *)

(* Simplified syntax of parsers of characters streams *)

open Pcaml;;
open Exparser;;

let var () = "buf";;
let empty loc =
  MLast.ExAcc
    (loc,
     MLast.ExAcc
       (loc, MLast.ExUid (loc, "Plexing"), MLast.ExUid (loc, "Lexbuf")),
     MLast.ExLid (loc, "empty"))
;;
let add_char loc c cl =
  MLast.ExApp
    (loc,
     MLast.ExApp
       (loc,
        MLast.ExAcc
          (loc,
           MLast.ExAcc
             (loc, MLast.ExUid (loc, "Plexing"), MLast.ExUid (loc, "Lexbuf")),
           MLast.ExLid (loc, "add")),
        c),
     cl)
;;
let get_buf loc cl =
  MLast.ExApp
    (loc,
     MLast.ExAcc
       (loc,
        MLast.ExAcc
          (loc, MLast.ExUid (loc, "Plexing"), MLast.ExUid (loc, "Lexbuf")),
        MLast.ExLid (loc, "get")),
     cl)
;;

let fresh_c cl =
  let n =
    List.fold_left
      (fun n c ->
         match c with
           MLast.ExLid (_, _) -> n + 1
         | _ -> n)
      0 cl
  in
  if n = 0 then "c" else "c" ^ string_of_int n
;;

let accum_chars loc cl =
  List.fold_right (add_char loc) cl (MLast.ExLid (loc, var ()))
;;

let conv_rules loc rl =
  List.map
    (fun (sl, cl, a) ->
       let a =
         let b = accum_chars loc cl in
         match a with
           Some e -> e
         | None -> b
       in
       List.rev sl, None, a)
    rl
;;

let mk_lexer loc rl = cparser loc None (conv_rules loc rl);;

let mk_lexer_match loc e rl = cparser_match loc e None (conv_rules loc rl);;

(* group together consecutive rules just containing one character *)
let isolate_char_patt_list =
  let rec loop pl =
    function
      ([SpTrm (_, p, None), SpoNoth], [_], None) :: rl ->
        let p =
          match p with
            MLast.PaChr (_, _) -> p
          | MLast.PaAli (_, p, MLast.PaLid (_, _)) -> p
          | p -> p
        in
        loop (p :: pl) rl
    | rl -> List.rev pl, rl
  in
  loop []
;;

let or_patt_of_patt_list loc =
  function
    p :: pl -> List.fold_left (fun p1 p2 -> MLast.PaOrp (loc, p1, p2)) p pl
  | [] -> invalid_arg "or_patt_of_patt_list"
;;

let isolate_char_patt loc rl =
  match isolate_char_patt_list rl with
    ([] | [_]), _ -> None, rl
  | pl, rl -> Some (or_patt_of_patt_list loc pl), rl
;;

let make_rules loc rl sl cl errk =
  match isolate_char_patt loc rl with
    Some p, [] ->
      let c = fresh_c cl in
      let s =
        let p = MLast.PaAli (loc, p, MLast.PaLid (loc, c)) in
        SpTrm (loc, p, None), errk
      in
      s :: sl, MLast.ExLid (loc, c) :: cl
  | x ->
      let rl =
        match x with
          Some p, rl ->
            let r =
              let p = MLast.PaAli (loc, p, MLast.PaLid (loc, "c")) in
              let e = MLast.ExLid (loc, "c") in
              [SpTrm (loc, p, None), SpoNoth], [e], None
            in
            r :: rl
        | None, rl -> rl
      in
      let errk =
        match List.rev rl with
          ([], _, _) :: _ -> SpoBang
        | _ -> errk
      in
      let sl =
        if cl = [] then sl
        else
          let s =
            let b = accum_chars loc cl in
            let e = cparser loc None [[], None, b] in
            SpNtr (loc, MLast.PaLid (loc, var ()), e), SpoBang
          in
          s :: sl
      in
      let s =
        let e = mk_lexer loc rl in
        SpNtr (loc, MLast.PaLid (loc, var ()), e), errk
      in
      s :: sl, []
;;

let make_any loc norec sl cl errk =
  let (p, cl) =
    if norec then MLast.PaAny loc, cl
    else
      let c = fresh_c cl in MLast.PaLid (loc, c), MLast.ExLid (loc, c) :: cl
  in
  let s = SpTrm (loc, p, None), errk in s :: sl, cl
;;

let fold_string_chars f s a =
  let rec loop i a =
    if i = String.length s then a
    else let c = Char.escaped s.[i] in loop (i + 1) (f c a)
  in
  loop 0 a
;;

let make_char loc c norec sl cl errk =
  let s = SpTrm (loc, MLast.PaChr (loc, c), None), errk in
  let cl = if norec then cl else MLast.ExChr (loc, c) :: cl in s :: sl, cl
;;

let make_chars loc s norec sl cl errk =
  let s = Plexing.eval_string loc s in
  let rec loop i sl cl =
    if i = String.length s then sl, cl
    else
      let c = Versdep.char_escaped s.[i] in
      let (sl, cl) = make_char loc c norec sl cl errk in loop (i + 1) sl cl
  in
  loop 0 sl cl
;;

let make_range loc c1 c2 norec sl cl errk =
  let p = MLast.PaRng (loc, MLast.PaChr (loc, c1), MLast.PaChr (loc, c2)) in
  let c = fresh_c cl in
  let s =
    let p = if norec then p else MLast.PaAli (loc, p, MLast.PaLid (loc, c)) in
    SpTrm (loc, p, None), errk
  in
  let cl = if norec then cl else MLast.ExLid (loc, c) :: cl in s :: sl, cl
;;

let make_sub_lexer loc f sl cl errk =
  let s =
    let buf = accum_chars loc cl in
    let e = MLast.ExApp (loc, f, buf) in
    let p = MLast.PaLid (loc, var ()) in SpNtr (loc, p, e), errk
  in
  s :: sl, []
;;

let make_lookahd loc pll sl cl errk =
  let s = SpLhd (loc, pll), errk in s :: sl, cl
;;

let gcl = ref [];;

Grammar.extend
  (let _ = (expr : 'expr Grammar.Entry.e) in
   let grammar_entry_create s =
     Grammar.create_local_entry (Grammar.of_entry expr) s
   in
   let rules : 'rules Grammar.Entry.e = grammar_entry_create "rules"
   and rule : 'rule Grammar.Entry.e = grammar_entry_create "rule"
   and symb_list : 'symb_list Grammar.Entry.e =
     grammar_entry_create "symb_list"
   and symbs : 'symbs Grammar.Entry.e = grammar_entry_create "symbs"
   and symb : 'symb Grammar.Entry.e = grammar_entry_create "symb"
   and simple_expr : 'simple_expr Grammar.Entry.e =
     grammar_entry_create "simple_expr"
   and lookahead : 'lookahead Grammar.Entry.e =
     grammar_entry_create "lookahead"
   and lookahead_char : 'lookahead_char Grammar.Entry.e =
     grammar_entry_create "lookahead_char"
   and no_rec : 'no_rec Grammar.Entry.e = grammar_entry_create "no_rec"
   and err_kont : 'err_kont Grammar.Entry.e = grammar_entry_create "err_kont"
   and act : 'act Grammar.Entry.e = grammar_entry_create "act" in
   [Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
    Some (Gramext.Like "match"),
    [None, None,
     [[Gramext.Stoken ("", "match"); Gramext.Sself;
       Gramext.Stoken ("", "with"); Gramext.Stoken ("", "lexer");
       Gramext.Snterm (Grammar.Entry.obj (rules : 'rules Grammar.Entry.e))],
      Gramext.action
        (fun (rl : 'rules) _ _ (e : 'expr) _ (loc : Ploc.t) ->
           (mk_lexer_match loc e rl : 'expr));
      [Gramext.Stoken ("", "lexer");
       Gramext.Snterm (Grammar.Entry.obj (rules : 'rules Grammar.Entry.e))],
      Gramext.action
        (fun (rl : 'rules) _ (loc : Ploc.t) ->
           (let rl =
              match isolate_char_patt loc rl with
                Some p, rl ->
                  let p = MLast.PaAli (loc, p, MLast.PaLid (loc, "c")) in
                  let e = MLast.ExLid (loc, "c") in
                  ([SpTrm (loc, p, None), SpoNoth], [e], None) :: rl
              | None, rl -> rl
            in
            MLast.ExFun
              (loc, [MLast.PaLid (loc, var ()), None, mk_lexer loc rl]) :
            'expr))]];
    Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
    Some (Gramext.Level "simple"),
    [None, None,
     [[Gramext.Stoken ("", "$"); Gramext.Stoken ("LIDENT", "pos")],
      Gramext.action
        (fun _ _ (loc : Ploc.t) ->
           (MLast.ExApp
              (loc,
               MLast.ExAcc
                 (loc, MLast.ExUid (loc, "Stream"),
                  MLast.ExLid (loc, "count")),
               MLast.ExLid (loc, strm_n)) :
            'expr));
      [Gramext.Stoken ("", "$"); Gramext.Stoken ("LIDENT", "empty")],
      Gramext.action (fun _ _ (loc : Ploc.t) -> (empty loc : 'expr));
      [Gramext.Stoken ("", "$"); Gramext.Stoken ("LIDENT", "buf")],
      Gramext.action
        (fun _ _ (loc : Ploc.t) ->
           (get_buf loc (accum_chars loc !gcl) : 'expr));
      [Gramext.Stoken ("", "$"); Gramext.Stoken ("LIDENT", "add");
       Gramext.Snterm
         (Grammar.Entry.obj (simple_expr : 'simple_expr Grammar.Entry.e))],
      Gramext.action
        (fun (e : 'simple_expr) _ _ (loc : Ploc.t) ->
           (add_char loc e (accum_chars loc !gcl) : 'expr));
      [Gramext.Stoken ("", "$"); Gramext.Stoken ("LIDENT", "add");
       Gramext.Stoken ("STRING", "")],
      Gramext.action
        (fun (s : string) _ _ (loc : Ploc.t) ->
           (let s = Plexing.eval_string loc s in
            let rec loop v i =
              if i = String.length s then v
              else
                let c = Char.escaped s.[i] in
                loop (add_char loc (MLast.ExChr (loc, c)) v) (i + 1)
            in
            loop (accum_chars loc !gcl) 0 :
            'expr))]];
    Grammar.Entry.obj (rules : 'rules Grammar.Entry.e), None,
    [None, None,
     [[Gramext.Stoken ("", "[");
       Gramext.Slist0sep
         (Gramext.Snterm (Grammar.Entry.obj (rule : 'rule Grammar.Entry.e)),
          Gramext.Stoken ("", "|"), false);
       Gramext.Stoken ("", "]")],
      Gramext.action
        (fun _ (rl : 'rule list) _ (loc : Ploc.t) -> (rl : 'rules))]];
    Grammar.Entry.obj (rule : 'rule Grammar.Entry.e), None,
    [None, None,
     [[Gramext.Snterm
         (Grammar.Entry.obj (symb_list : 'symb_list Grammar.Entry.e));
       Gramext.Snterm (Grammar.Entry.obj (act : 'act Grammar.Entry.e))],
      Gramext.action
        (fun (a : 'act) (sl, cl : 'symb_list) (loc : Ploc.t) ->
           (gcl := []; sl, cl, a : 'rule))]];
    Grammar.Entry.obj (symb_list : 'symb_list Grammar.Entry.e), None,
    [None, None,
     [[Gramext.Snterm (Grammar.Entry.obj (symbs : 'symbs Grammar.Entry.e))],
      Gramext.action
        (fun (sl, cl : 'symbs) (loc : Ploc.t) ->
           (gcl := cl; sl, cl : 'symb_list))]];
    Grammar.Entry.obj (symbs : 'symbs Grammar.Entry.e), None,
    [None, None,
     [[], Gramext.action (fun (loc : Ploc.t) -> ([], [] : 'symbs));
      [Gramext.Sself;
       Gramext.Snterm (Grammar.Entry.obj (symb : 'symb Grammar.Entry.e));
       Gramext.Snterm
         (Grammar.Entry.obj (err_kont : 'err_kont Grammar.Entry.e))],
      Gramext.action
        (fun (kont : 'err_kont) (f : 'symb) (sl, cl : 'symbs)
             (loc : Ploc.t) ->
           (f sl cl kont : 'symbs))]];
    Grammar.Entry.obj (symb : 'symb Grammar.Entry.e), None,
    [None, None,
     [[Gramext.Snterm (Grammar.Entry.obj (rules : 'rules Grammar.Entry.e))],
      Gramext.action
        (fun (rl : 'rules) (loc : Ploc.t) -> (make_rules loc rl : 'symb));
      [Gramext.Stoken ("", "?="); Gramext.Stoken ("", "[");
       Gramext.Slist1sep
         (Gramext.Snterm
            (Grammar.Entry.obj (lookahead : 'lookahead Grammar.Entry.e)),
          Gramext.Stoken ("", "|"), false);
       Gramext.Stoken ("", "]")],
      Gramext.action
        (fun _ (pll : 'lookahead list) _ _ (loc : Ploc.t) ->
           (make_lookahd loc pll : 'symb));
      [Gramext.Snterm
         (Grammar.Entry.obj (simple_expr : 'simple_expr Grammar.Entry.e))],
      Gramext.action
        (fun (f : 'simple_expr) (loc : Ploc.t) ->
           (make_sub_lexer loc f : 'symb));
      [Gramext.Stoken ("CHAR", ""); Gramext.Stoken ("", "-");
       Gramext.Stoken ("CHAR", "");
       Gramext.Snterm (Grammar.Entry.obj (no_rec : 'no_rec Grammar.Entry.e))],
      Gramext.action
        (fun (norec : 'no_rec) (d : string) _ (c : string) (loc : Ploc.t) ->
           (make_range loc c d norec : 'symb));
      [Gramext.Stoken ("CHAR", "");
       Gramext.Snterm (Grammar.Entry.obj (no_rec : 'no_rec Grammar.Entry.e))],
      Gramext.action
        (fun (norec : 'no_rec) (c : string) (loc : Ploc.t) ->
           (make_char loc c norec : 'symb));
      [Gramext.Stoken ("STRING", "");
       Gramext.Snterm (Grammar.Entry.obj (no_rec : 'no_rec Grammar.Entry.e))],
      Gramext.action
        (fun (norec : 'no_rec) (s : string) (loc : Ploc.t) ->
           (make_chars loc s norec : 'symb));
      [Gramext.Stoken ("", "_");
       Gramext.Snterm (Grammar.Entry.obj (no_rec : 'no_rec Grammar.Entry.e))],
      Gramext.action
        (fun (norec : 'no_rec) _ (loc : Ploc.t) ->
           (make_any loc norec : 'symb))]];
    Grammar.Entry.obj (simple_expr : 'simple_expr Grammar.Entry.e), None,
    [None, None,
     [[Gramext.Stoken ("", "(");
       Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e));
       Gramext.Stoken ("", ")")],
      Gramext.action
        (fun _ (e : 'expr) _ (loc : Ploc.t) -> (e : 'simple_expr));
      [Gramext.Stoken ("CHAR", "")],
      Gramext.action
        (fun (c : string) (loc : Ploc.t) ->
           (MLast.ExChr (loc, c) : 'simple_expr));
      [Gramext.Stoken ("LIDENT", "")],
      Gramext.action
        (fun (i : string) (loc : Ploc.t) ->
           (MLast.ExLid (loc, i) : 'simple_expr))]];
    Grammar.Entry.obj (lookahead : 'lookahead Grammar.Entry.e), None,
    [None, None,
     [[Gramext.Stoken ("STRING", "")],
      Gramext.action
        (fun (s : string) (loc : Ploc.t) ->
           (let s = Plexing.eval_string loc s in
            List.rev
              (fold_string_chars (fun c pl -> MLast.PaChr (loc, c) :: pl) s
                 []) :
            'lookahead));
      [Gramext.Slist1
         (Gramext.Snterm
            (Grammar.Entry.obj
               (lookahead_char : 'lookahead_char Grammar.Entry.e)))],
      Gramext.action
        (fun (pl : 'lookahead_char list) (loc : Ploc.t) ->
           (pl : 'lookahead))]];
    Grammar.Entry.obj (lookahead_char : 'lookahead_char Grammar.Entry.e),
    None,
    [None, None,
     [[Gramext.Stoken ("", "_")],
      Gramext.action
        (fun _ (loc : Ploc.t) -> (MLast.PaAny loc : 'lookahead_char));
      [Gramext.Stoken ("CHAR", ""); Gramext.Stoken ("", "-");
       Gramext.Stoken ("CHAR", "")],
      Gramext.action
        (fun (d : string) _ (c : string) (loc : Ploc.t) ->
           (MLast.PaRng (loc, MLast.PaChr (loc, c), MLast.PaChr (loc, d)) :
            'lookahead_char));
      [Gramext.Stoken ("CHAR", "")],
      Gramext.action
        (fun (c : string) (loc : Ploc.t) ->
           (MLast.PaChr (loc, c) : 'lookahead_char))]];
    Grammar.Entry.obj (no_rec : 'no_rec Grammar.Entry.e), None,
    [None, None,
     [[], Gramext.action (fun (loc : Ploc.t) -> (false : 'no_rec));
      [Gramext.Stoken ("", "/")],
      Gramext.action (fun _ (loc : Ploc.t) -> (true : 'no_rec))]];
    Grammar.Entry.obj (err_kont : 'err_kont Grammar.Entry.e), None,
    [None, None,
     [[], Gramext.action (fun (loc : Ploc.t) -> (SpoNoth : 'err_kont));
      [Gramext.Stoken ("", "?");
       Gramext.Snterm
         (Grammar.Entry.obj (simple_expr : 'simple_expr Grammar.Entry.e))],
      Gramext.action
        (fun (e : 'simple_expr) _ (loc : Ploc.t) -> (SpoQues e : 'err_kont));
      [Gramext.Stoken ("", "?"); Gramext.Stoken ("STRING", "")],
      Gramext.action
        (fun (s : string) _ (loc : Ploc.t) ->
           (SpoQues (MLast.ExStr (loc, s)) : 'err_kont));
      [Gramext.Stoken ("", "!")],
      Gramext.action (fun _ (loc : Ploc.t) -> (SpoBang : 'err_kont))]];
    Grammar.Entry.obj (act : 'act Grammar.Entry.e), None,
    [None, None,
     [[], Gramext.action (fun (loc : Ploc.t) -> (None : 'act));
      [Gramext.Stoken ("", "->");
       Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
      Gramext.action
        (fun (e : 'expr) _ (loc : Ploc.t) -> (Some e : 'act))]]]);;
