(* camlp5r *)
(* pa_extend_m.ml,v *)
(* Copyright (c) INRIA 2007-2016 *)

(* #load "pa_extend.cmo" *)
(* #load "q_MLast.cmo" *)

open Pa_extend;;

Grammar.extend
  (let _ = (symbol : 'symbol Grammar.Entry.e) in
   let grammar_entry_create s =
     Grammar.create_local_entry (Grammar.of_entry symbol) s
   in
   let name : 'name Grammar.Entry.e = grammar_entry_create "name" in
   [Grammar.Entry.obj (symbol : 'symbol Grammar.Entry.e),
    Some (Gramext.Level "top"),
    [None, Some Gramext.NonA,
     [[Gramext.Stoken ("UIDENT", "SFLAG"); Gramext.Sself],
      Gramext.action
        (fun (s : 'symbol) _ (loc : Ploc.t) ->
           (ASquot (loc, ASflag (loc, s)) : 'symbol));
      [Gramext.Stoken ("UIDENT", "SOPT"); Gramext.Sself],
      Gramext.action
        (fun (s : 'symbol) _ (loc : Ploc.t) ->
           (ASquot (loc, ASopt (loc, s)) : 'symbol));
      [Gramext.Stoken ("UIDENT", "SLIST1"); Gramext.Sself;
       Gramext.Sopt
         (Gramext.srules
            [[Gramext.Stoken ("UIDENT", "SEP");
              Gramext.Snterm
                (Grammar.Entry.obj (symbol : 'symbol Grammar.Entry.e))],
             Gramext.action
               (fun (t : 'symbol) _ (loc : Ploc.t) -> (t, false : 'e__2))])],
      Gramext.action
        (fun (sep : 'e__2 option) (s : 'symbol) _ (loc : Ploc.t) ->
           (ASquot (loc, ASlist (loc, LML_1, s, sep)) : 'symbol));
      [Gramext.Stoken ("UIDENT", "SLIST0"); Gramext.Sself;
       Gramext.Sopt
         (Gramext.srules
            [[Gramext.Stoken ("UIDENT", "SEP");
              Gramext.Snterm
                (Grammar.Entry.obj (symbol : 'symbol Grammar.Entry.e))],
             Gramext.action
               (fun (t : 'symbol) _ (loc : Ploc.t) -> (t, false : 'e__1))])],
      Gramext.action
        (fun (sep : 'e__1 option) (s : 'symbol) _ (loc : Ploc.t) ->
           (ASquot (loc, ASlist (loc, LML_0, s, sep)) : 'symbol))]];
    Grammar.Entry.obj (symbol : 'symbol Grammar.Entry.e),
    Some (Gramext.Level "vala"),
    [None, None,
     [[Gramext.Stoken ("UIDENT", "SV"); Gramext.Snext;
       Gramext.Slist0 (Gramext.Stoken ("STRING", ""));
       Gramext.Sopt
         (Gramext.Snterm (Grammar.Entry.obj (name : 'name Grammar.Entry.e)))],
      Gramext.action
        (fun (oe : 'name option) (al : string list) (s : 'symbol) _
             (loc : Ploc.t) ->
           (ASvala2 (loc, s, al, oe) : 'symbol));
      [Gramext.Stoken ("UIDENT", "SV"); Gramext.Stoken ("UIDENT", "");
       Gramext.Slist0 (Gramext.Stoken ("STRING", ""));
       Gramext.Sopt
         (Gramext.Snterm (Grammar.Entry.obj (name : 'name Grammar.Entry.e)))],
      Gramext.action
        (fun (oe : 'name option) (al : string list) (x : string) _
             (loc : Ploc.t) ->
           (let s = AStok (loc, x, None) in ASvala2 (loc, s, al, oe) :
            'symbol));
      [Gramext.Stoken ("UIDENT", "SV"); Gramext.Stoken ("UIDENT", "NEXT");
       Gramext.Slist0 (Gramext.Stoken ("STRING", ""));
       Gramext.Sopt
         (Gramext.Snterm (Grammar.Entry.obj (name : 'name Grammar.Entry.e)))],
      Gramext.action
        (fun (oe : 'name option) (al : string list) _ _ (loc : Ploc.t) ->
           (let s = ASnext loc in ASvala2 (loc, s, al, oe) : 'symbol));
      [Gramext.Stoken ("UIDENT", "SV"); Gramext.Stoken ("UIDENT", "SELF");
       Gramext.Slist0 (Gramext.Stoken ("STRING", ""));
       Gramext.Sopt
         (Gramext.Snterm (Grammar.Entry.obj (name : 'name Grammar.Entry.e)))],
      Gramext.action
        (fun (oe : 'name option) (al : string list) _ _ (loc : Ploc.t) ->
           (let s = ASself loc in ASvala2 (loc, s, al, oe) : 'symbol))]];
    Grammar.Entry.obj (name : 'name Grammar.Entry.e), None,
    [None, None,
     [[Gramext.Stoken ("LIDENT", "")],
      Gramext.action
        (fun (i : string) (loc : Ploc.t) ->
           (i, MLast.ExLid (loc, i) : 'name))]]]);;
