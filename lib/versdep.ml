(* camlp5r pa_macro.cmo *)
(* $Id: versdep.ml,v 6.49 2014/04/14 01:51:09 deraugla Exp $ *)
(* Copyright (c) INRIA 2007-2012 *)

open Parsetree;
open Longident;
open Asttypes;

type choice 'a 'b =
  [ Left of 'a
  | Right of 'b ]
;

value sys_ocaml_version =
  IFDEF OCAML_1_06 THEN "1.06"
  ELSIFDEF OCAML_1_07 THEN "1.07"
  ELSIFDEF OCAML_2_00 THEN "2.00"
  ELSIFDEF OCAML_2_01 THEN "2.01"
  ELSIFDEF OCAML_2_02 THEN "2.02"
  ELSIFDEF OCAML_2_03 THEN "2.03"
  ELSIFDEF OCAML_2_04 THEN "2.04"
  ELSIFDEF OCAML_2_99 THEN "2.99"
  ELSIFDEF OCAML_3_00 THEN "3.00"
  ELSIFDEF OCAML_3_01 THEN "3.01"
  ELSIFDEF OCAML_3_02 THEN "3.02"
  ELSIFDEF OCAML_3_03 THEN "3.03"
  ELSIFDEF OCAML_3_04 THEN "3.04"
  ELSIFDEF OCAML_3_13_0_gadt THEN "3.13.0-gadt"
  ELSE Sys.ocaml_version END
;

value ocaml_location (fname, lnum, bolp, lnuml, bolpl, bp, ep) =
  IFDEF OCAML_VERSION <= OCAML_2_02 THEN
    {Location.loc_start = bp; Location.loc_end = ep}
  ELSIFDEF OCAML_VERSION <= OCAML_3_06 THEN
    {Location.loc_start = bp; Location.loc_end = ep;
     Location.loc_ghost = bp = 0 && ep = 0}
  ELSE
    let loc_at n lnum bolp =
      {Lexing.pos_fname = if lnum = -1 then "" else fname;
       Lexing.pos_lnum = lnum; Lexing.pos_bol = bolp; Lexing.pos_cnum = n}
    in
    {Location.loc_start = loc_at bp lnum bolp;
     Location.loc_end = loc_at ep lnuml bolpl;
     Location.loc_ghost = bp = 0 && ep = 0}
  END
;

IFDEF OCAML_VERSION >= OCAML_4_00 THEN
value loc_none =
  let loc =
    {Lexing.pos_fname = "_none_"; pos_lnum = 1; pos_bol = 0; pos_cnum = -1}
  in
  {Location.loc_start = loc;
   Location.loc_end = loc;
   Location.loc_ghost = True}
;
END;

value mkloc loc txt =
  IFDEF OCAML_VERSION < OCAML_4_00 THEN txt
  ELSE {Location.txt = txt; loc = loc} END
;
value mknoloc txt =
  IFDEF OCAML_VERSION < OCAML_4_00 THEN txt
  ELSE mkloc loc_none txt END
;

value ocaml_id_or_li_of_string_list loc sl =
  IFDEF OCAML_VERSION < OCAML_3_13_0 OR JOCAML THEN
    match List.rev sl with
    [ [s] -> Some s
    | _ -> None ]
  ELSE
    let mkli s =
      loop (fun s -> Lident s) where rec loop f =
        fun
        [ [i :: il] -> loop (fun s -> Ldot (f i) s) il
        | [] -> f s ]
    in
    match List.rev sl with
    [ [] -> None
    | [s :: sl] -> Some (mkli s (List.rev sl)) ]
  END
;

value list_map_check f l =
  loop [] l where rec loop rev_l =
    fun
    [ [x :: l] ->
        match f x with
        [ Some s -> loop [s :: rev_l] l
        | None -> None ]
    | [] -> Some (List.rev rev_l) ]
;

value ocaml_value_description t p =
  IFDEF OCAML_VERSION < OCAML_4_00 THEN {pval_type = t; pval_prim = p}
  ELSE {pval_type = t; pval_prim = p; pval_loc = t.ptyp_loc} END
;

value ocaml_class_type_field loc ctfd =
  IFDEF OCAML_VERSION < OCAML_4_00 THEN ctfd
  ELSE {pctf_desc = ctfd; pctf_loc = loc} END
;

value ocaml_class_field loc cfd =
  IFDEF OCAML_VERSION < OCAML_4_00 THEN cfd
  ELSE {pcf_desc = cfd; pcf_loc = loc} END
;

value ocaml_type_declaration params cl tk pf tm loc variance =
  IFDEF OCAML_VERSION = OCAML_3_13_0_gadt THEN
    Right
      {ptype_params = params; ptype_cstrs = cl; ptype_kind = tk;
       ptype_private = pf; ptype_manifest = tm; ptype_loc = loc;
       ptype_variance = variance}
  ELSE
    match list_map_check (fun s_opt -> s_opt) params with
    [ Some params ->
        IFDEF OCAML_VERSION <= OCAML_1_07 THEN
          let cl_opt =
            list_map_check
              (fun (t1, t2, loc) ->
                 match t1.ptyp_desc with
                 [ Ptyp_var s -> Some (s, t2, loc)
                 | _ -> None ])
              cl
          in
          match cl_opt with
          [ Some cl ->
              Right
                {ptype_params = params; ptype_cstrs = cl; ptype_kind = tk;
                 ptype_manifest = tm; ptype_loc = loc}
          | None ->
               Left "no such 'with' constraint in this ocaml version" ]
        ELSIFDEF OCAML_VERSION <= OCAML_3_00 THEN
          Right
            {ptype_params = params; ptype_cstrs = cl; ptype_kind = tk;
             ptype_manifest = tm; ptype_loc = loc}
        ELSIFDEF OCAML_VERSION < OCAML_3_11 THEN
          Right
            {ptype_params = params; ptype_cstrs = cl; ptype_kind = tk;
             ptype_manifest = tm; ptype_loc = loc; ptype_variance = variance}
        ELSIFDEF OCAML_VERSION < OCAML_3_13_0 OR JOCAML THEN
          Right
            {ptype_params = params; ptype_cstrs = cl; ptype_kind = tk;
             ptype_private = pf; ptype_manifest = tm; ptype_loc = loc;
             ptype_variance = variance}
        ELSE
          let params = List.map (fun os -> Some (mknoloc os)) params in
          Right
            {ptype_params = params; ptype_cstrs = cl; ptype_kind = tk;
             ptype_private = pf; ptype_manifest = tm; ptype_loc = loc;
             ptype_variance = variance}
        END
    | None -> Left "no '_' type param in this ocaml version" ]
  END
;

value ocaml_class_type =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSE Some (fun d loc -> {pcty_desc = d; pcty_loc = loc}) END
;

value ocaml_class_expr =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSE Some (fun d loc -> {pcl_desc = d; pcl_loc = loc}) END
;

value ocaml_class_structure p cil =
  IFDEF OCAML_VERSION <= OCAML_4_00 THEN (p, cil)
  ELSE {pcstr_pat = p; pcstr_fields = cil} END
;

value ocaml_pmty_ident loc li = Pmty_ident (mkloc loc li);

value ocaml_pmty_functor sloc s mt1 mt2 = Pmty_functor (mkloc sloc s) mt1 mt2;

value ocaml_pmty_typeof =
  IFDEF OCAML_VERSION < OCAML_3_12 THEN None
  ELSE Some (fun me -> Pmty_typeof me) END
;

value ocaml_pmty_with mt lcl =
  let lcl = List.map (fun (s, c) → (mknoloc s, c)) lcl in
  Pmty_with mt lcl
;

value ocaml_ptype_abstract =
  IFDEF OCAML_VERSION <= OCAML_3_08_4 OR OCAML_VERSION >= OCAML_3_11 THEN
    Ptype_abstract
  ELSE
    Ptype_private
  END
;

value ocaml_ptype_record ltl priv =
  IFDEF OCAML_VERSION <= OCAML_3_08_4 THEN
    let ltl = List.map (fun (n, m, t, _) -> (n, m, t)) ltl in
    IFDEF OCAML_VERSION <= OCAML_3_06 THEN
      Ptype_record ltl
    ELSE
      let priv = if priv then Private else Public in
      Ptype_record ltl priv
    END
  ELSIFDEF OCAML_VERSION < OCAML_3_11 THEN
    let priv = if priv then Private else Public in
    Ptype_record ltl priv
  ELSIFDEF OCAML_VERSION < OCAML_4_00 THEN
    Ptype_record ltl
  ELSE
    Ptype_record
      (List.map (fun (s, mf, ct, loc) → (mkloc loc s, mf, ct, loc)) ltl)
  END
;

value ocaml_ptype_variant ctl priv =
  IFDEF OCAML_VERSION = OCAML_3_13_0_gadt THEN
    Some (Ptype_variant ctl)
  ELSE
    try
      IFDEF OCAML_VERSION <= OCAML_3_08_4 THEN
        let ctl =
          List.map
            (fun (c, tl, rto, loc) ->
               if rto <> None then raise Exit else (c, tl))
            ctl
        in
        IFDEF OCAML_VERSION <= OCAML_3_06 THEN
          Some (Ptype_variant ctl)
        ELSE
          let priv = if priv then Private else Public in
          Some (Ptype_variant ctl priv)
        END
      ELSIFDEF OCAML_VERSION < OCAML_3_11 THEN
        let ctl =
          List.map
            (fun (c, tl, rto, loc) ->
               if rto <> None then raise Exit else (c, tl, loc))
            ctl
        in
          let priv = if priv then Private else Public in
          Some (Ptype_variant ctl priv)
      ELSIFDEF OCAML_VERSION < OCAML_3_13_0 OR JOCAML THEN
        let ctl =
          List.map
            (fun (c, tl, rto, loc) ->
               if rto <> None then raise Exit else (c, tl, loc))
            ctl
        in
          Some (Ptype_variant ctl)
      ELSE
        let ctl =
          List.map
            (fun (c, tl, rto, loc) ->
               if rto <> None then raise Exit else (mknoloc c, tl, None, loc))
            ctl
        in
          Some (Ptype_variant ctl)
      END
    with
    [ Exit -> None ]
  END
;

value ocaml_ptyp_arrow lab t1 t2 =
  IFDEF OCAML_VERSION <= OCAML_2_04 THEN Ptyp_arrow t1 t2
  ELSE Ptyp_arrow lab t1 t2 END
;

value ocaml_ptyp_class li tl ll =
  IFDEF OCAML_VERSION <= OCAML_2_04 THEN Ptyp_class li tl
  ELSE Ptyp_class (mknoloc li) tl ll END
;

value ocaml_ptyp_constr li tl = Ptyp_constr (mknoloc li) tl;

value ocaml_ptyp_object ml =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN Ptyp_object ml
  ELSE Ptyp_object ml Closed END
;

value ocaml_ptyp_package =
  IFDEF OCAML_VERSION < OCAML_3_12_0 THEN None
  ELSE Some (fun pt -> Ptyp_package pt) END
;

value ocaml_ptyp_poly =
  IFDEF OCAML_VERSION <= OCAML_3_04 THEN None
  ELSE Some (fun cl t -> Ptyp_poly cl t) END
;

value ocaml_ptyp_variant catl clos sl_opt =
  IFDEF OCAML_VERSION <= OCAML_2_04 THEN None
  ELSIFDEF OCAML_VERSION <= OCAML_3_02 THEN
    try
      let catl =
        List.map
          (fun
           [ Left (c, a, tl) -> (c, a, tl)
           | Right t -> raise Exit ])
          catl
      in
      let sl = match sl_opt with [ Some sl -> sl | None -> [] ] in
      Some (Ptyp_variant catl clos sl)
    with
    [ Exit -> None ]
  ELSE
    let catl =
      List.map
        (fun
         [ Left (c, a, tl) -> Rtag c a tl
         | Right t -> Rinherit t ])
        catl
    in
    Some (Ptyp_variant catl clos sl_opt)
  END
;

value ocaml_package_type li ltl =
  (mknoloc li, List.map (fun (li, t) → (mkloc t.ptyp_loc li, t)) ltl)
;

value ocaml_const_string s =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN Const_string s
  ELSE Const_string (s, None) END
;

value ocaml_const_int32 =
  IFDEF OCAML_VERSION <= OCAML_3_06 THEN None
  ELSE Some (fun s -> Const_int32 (Int32.of_string s)) END
;

value ocaml_const_int64 =
  IFDEF OCAML_VERSION <= OCAML_3_06 THEN None
  ELSE Some (fun s -> Const_int64 (Int64.of_string s)) END
;

value ocaml_const_nativeint =
  IFDEF OCAML_VERSION <= OCAML_3_06 THEN None
  ELSE Some (fun s -> Const_nativeint (Nativeint.of_string s)) END
;

value ocaml_mktyp loc x =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN {ptyp_desc = x; ptyp_loc = loc}
  ELSE {ptyp_desc = x; ptyp_loc = loc; ptyp_attributes = []} END
;
value ocaml_mkpat loc x =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN {ppat_desc = x; ppat_loc = loc}
  ELSE {ppat_desc = x; ppat_loc = loc; ppat_attributes = []} END
;
value ocaml_mkexp loc x =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN {pexp_desc = x; pexp_loc = loc}
  ELSE {pexp_desc = x; pexp_loc = loc; pexp_attributes = []} END
;
value ocaml_mkmty loc x =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN {pmty_desc = x; pmty_loc = loc}
  ELSE {pmty_desc = x; pmty_loc = loc; pmty_attributes = []} END
;
value ocaml_mkmod loc x =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN {pmod_desc = x; pmod_loc = loc}
  ELSE {pmod_desc = x; pmod_loc = loc; pmod_attributes = []} END
;
value ocaml_mkfield loc (lab, x) fl =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN
    [{pfield_desc = Pfield lab x; pfield_loc = loc} :: fl]
  ELSE [(lab, x) :: fl] END
;
value ocaml_mkfield_var loc =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN
    [{pfield_desc = Pfield_var; pfield_loc = loc}]
  ELSE [] END
;

value ocaml_pexp_apply f lel =
  IFDEF OCAML_VERSION <= OCAML_2_04 THEN Pexp_apply f (List.map snd lel)
  ELSE Pexp_apply f lel END
;

value ocaml_pexp_assertfalse fname loc =
  IFDEF OCAML_VERSION <= OCAML_3_00 THEN
    let ghexp d = {pexp_desc = d; pexp_loc = loc} in
    let triple =
      ghexp (Pexp_tuple
             [ghexp (Pexp_constant (Const_string fname));
              ghexp (Pexp_constant (Const_int loc.Location.loc_start));
              ghexp (Pexp_constant (Const_int loc.Location.loc_end))])
    in
    let excep = Ldot (Lident "Pervasives") "Assert_failure" in
    let bucket = ghexp (Pexp_construct excep (Some triple) False) in
    let raise_ = ghexp (Pexp_ident (Ldot (Lident "Pervasives") "raise")) in
    ocaml_pexp_apply raise_ [("", bucket)]
  ELSE Pexp_assertfalse END
;

value ocaml_pexp_assert fname loc e =
  IFDEF OCAML_VERSION <= OCAML_3_00 THEN
    let ghexp d = {pexp_desc = d; pexp_loc = loc} in
    let ghpat d = {ppat_desc = d; ppat_loc = loc} in
    let triple =
      ghexp (Pexp_tuple
             [ghexp (Pexp_constant (Const_string fname));
              ghexp (Pexp_constant (Const_int loc.Location.loc_start));
              ghexp (Pexp_constant (Const_int loc.Location.loc_end))])
    in
    let excep = Ldot (Lident "Pervasives") "Assert_failure" in
    let bucket = ghexp (Pexp_construct excep (Some triple) False) in
    let raise_ = ghexp (Pexp_ident (Ldot (Lident "Pervasives") "raise")) in
    let raise_af = ghexp (ocaml_pexp_apply raise_ [("", bucket)]) in
    let under = ghpat Ppat_any in
    let false_ = ghexp (Pexp_construct (Lident "false") None False) in
    let try_e = ghexp (Pexp_try e [(under, false_)]) in

    let not_ = ghexp (Pexp_ident (Ldot (Lident "Pervasives") "not")) in
    let not_try_e = ghexp (ocaml_pexp_apply not_ [("", try_e)]) in
    Pexp_ifthenelse not_try_e raise_af None
  ELSE Pexp_assert e END
;

value ocaml_pexp_constraint e ot1 ot2 =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN Pexp_constraint e ot1 ot2
  ELSE
    match ot2 with
    | Some t2 -> Pexp_coerce e ot1 t2
    | None ->
        match ot1 with
        | Some t1 -> Pexp_constraint e t1
        | None -> failwith "internal error: ocaml_pexp_constraint"
        end
    end
  END
;

value ocaml_pexp_construct loc li po chk_arity =
  Pexp_construct (mkloc loc li) po chk_arity
;

value ocaml_pexp_construct_args =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN
    fun
    [ Pexp_construct li po chk_arity -> Some (li.txt, li.loc, po, chk_arity)
    | _ -> None ]
  ELSE
    fun
    [ Pexp_construct li po -> Some (li.txt, li.loc, po, 0)
    | _ -> None ]
  END
;

value ocaml_pexp_field loc e li = Pexp_field e (mkloc loc li);

value ocaml_pexp_for i e1 e2 df e = Pexp_for (mknoloc i) e1 e2 df e;

value ocaml_case (p, wo, loc, e) =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN
    match wo with
    | Some w -> (p, ocaml_mkexp loc (Pexp_when w e))
    | None -> (p, e)
    end
  ELSE
    {pc_lhs = p; pc_guard = wo; pc_rhs = e}
  END
;

value ocaml_pexp_function lab eo pel =
  IFDEF OCAML_VERSION <= OCAML_2_04 THEN Pexp_function pel
  ELSIFDEF OCAML_VERSION < OCAML_4_02_0 THEN Pexp_function lab eo pel
  ELSE
    if lab = "" && eo = None then Pexp_function pel
    else
      match pel with
      | [{pc_lhs = p; pc_guard = None; pc_rhs = e}] -> Pexp_fun lab eo p e
      | _ -> failwith "internal error: bad ast in ocaml_pexp_function"
      end
  END
;

value ocaml_pexp_lazy =
  IFDEF OCAML_VERSION <= OCAML_3_04 THEN None
  ELSE Some (fun e -> Pexp_lazy e) END
;

value ocaml_pexp_ident li = Pexp_ident (mknoloc li);

value ocaml_pexp_letmodule =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSE Some (fun i me e -> Pexp_letmodule (mknoloc i) me e) END
;

value ocaml_pexp_new loc li = Pexp_new (mkloc loc li);

value ocaml_pexp_newtype =
  IFDEF OCAML_VERSION < OCAML_3_12_0 THEN None
  ELSE Some (fun s e -> Pexp_newtype s e) END
;

value ocaml_pexp_object =
  IFDEF OCAML_VERSION <= OCAML_3_07 THEN None
  ELSE Some (fun cs -> Pexp_object cs) END
;

value ocaml_pexp_open =
  IFDEF OCAML_VERSION < OCAML_3_12 THEN None
  ELSIFDEF OCAML_VERSION < OCAML_4_01 THEN
    Some (fun li e -> Pexp_open (mknoloc li) e)
  ELSE
    Some (fun li e -> Pexp_open Fresh (mknoloc li) e)
  END
;

value ocaml_pexp_override sel =
  let sel = List.map (fun (s, e) → (mknoloc s, e)) sel in
  Pexp_override sel
;

value ocaml_pexp_pack =
  IFDEF OCAML_VERSION < OCAML_3_12 THEN None
  ELSIFDEF OCAML_VERSION < OCAML_3_13_0 THEN
    Some (Left (fun me pt -> Pexp_pack me pt))
  ELSE
    (Some (Right (fun me -> Pexp_pack me, fun pt -> Ptyp_package pt)) :
     option (choice ('a -> 'b -> 'c) 'd))
  END
;

value ocaml_pexp_poly =
  IFDEF OCAML_VERSION <= OCAML_3_04 THEN None
  ELSE Some (fun e t -> Pexp_poly e t) END
;

value ocaml_pexp_record lel eo =
  let lel = List.map (fun (li, loc, e) → (mkloc loc li, e)) lel in
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN
    match eo with
    [ Some _ -> invalid_arg "ocaml_pexp_record"
    | None -> Pexp_record lel ]
  ELSE
    Pexp_record lel eo
  END
;

value ocaml_pexp_setinstvar s e = Pexp_setinstvar (mknoloc s) e;

value ocaml_pexp_variant =
  IFDEF OCAML_VERSION <= OCAML_2_04 THEN None
  ELSE
    let pexp_variant_pat =
      fun
      [ Pexp_variant lab eo -> Some (lab, eo)
      | _ -> None ]
    in
    let pexp_variant (lab, eo) = Pexp_variant lab eo in
    Some (pexp_variant_pat, pexp_variant)
  END
;

value ocaml_value_binding p e =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN (p, e)
  ELSE {pvb_pat = p; pvb_expr = e; pvb_attributes = []} END
;

value ocaml_ppat_alias p i iloc = Ppat_alias p (mkloc iloc i);

value ocaml_ppat_array =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSE Some (fun pl -> Ppat_array pl) END
;

value ocaml_ppat_construct li li_loc po chk_arity  =
  IFDEF OCAML_VERSION < OCAML_4_00 THEN
    Ppat_construct li po chk_arity
  ELSE
    Ppat_construct (mkloc li_loc li) po chk_arity
  END
;

value ocaml_ppat_construct_args =
  fun
  [ Ppat_construct li po chk_arity ->
      IFDEF OCAML_VERSION < OCAML_4_00 THEN Some (li, 0, po, chk_arity)
      ELSE Some (li.txt, li.loc, po, chk_arity) END 
  | _ -> None ]
;

value ocaml_ppat_lazy =
  IFDEF OCAML_VERSION >= OCAML_3_11 THEN Some (fun p -> Ppat_lazy p)
  ELSE None END
;

value ocaml_ppat_record lpl is_closed =
  let lpl = List.map (fun (li, loc, p) → (mkloc loc li, p)) lpl in
  IFDEF OCAML_VERSION < OCAML_3_12 THEN Ppat_record lpl
  ELSE Ppat_record lpl (if is_closed then Closed else Open) END
;

value ocaml_ppat_type =
  IFDEF OCAML_VERSION <= OCAML_2_99 THEN None
  ELSE Some (fun loc li -> Ppat_type (mkloc loc li)) END
;

value ocaml_ppat_unpack =
  IFDEF OCAML_VERSION < OCAML_3_13_0 OR JOCAML THEN None
  ELSE
    Some (fun loc s -> Ppat_unpack (mkloc loc s), fun pt -> Ptyp_package pt)
  END
;

value ocaml_ppat_var loc s = Ppat_var (mkloc loc s);

value ocaml_ppat_variant =
  IFDEF OCAML_VERSION <= OCAML_2_04 THEN None
  ELSE
    let ppat_variant_pat =
      fun
      [ Ppat_variant lab po -> Some (lab, po)
      | _ -> None ]
    in
    let ppat_variant (lab, po) = Ppat_variant lab po in
    Some (ppat_variant_pat, ppat_variant)
  END
;

value ocaml_psig_class_type =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSE Some (fun ctl -> Psig_class_type ctl) END
;

value ocaml_psig_exception s ed = Psig_exception (mknoloc s) ed;

value ocaml_psig_include mt =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN Psig_include mt
  ELSE Psig_include mt [] END
;

value ocaml_psig_module s mt = Psig_module (mknoloc s) mt;

value ocaml_psig_modtype loc s mto =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN
    let mtd =
      match mto with
      | None -> Pmodtype_abstract
      | Some t -> Pmodtype_manifest t
      end
    in
    Psig_modtype (mknoloc s) mtd
  ELSE
    let pmtd =
      {pmtd_name = mkloc loc s; pmtd_type = mto; pmtd_attributes = [];
       pmtd_loc = loc}
    in
    Psig_modtype pmtd
  END
;

value ocaml_psig_open li =
  IFDEF OCAML_VERSION < OCAML_4_01 THEN Psig_open (mknoloc li)
  ELSE Psig_open Fresh (mknoloc li) END
;

value ocaml_psig_recmodule =
  IFDEF OCAML_VERSION <= OCAML_3_06 THEN None
  ELSE
    let f ntl =
      let ntl = List.map (fun (s, mt) → (mknoloc s, mt)) ntl in
      Psig_recmodule ntl
    in
    Some f
  END
;

value ocaml_psig_type stl =
  let stl = List.map (fun (s, t) → (mknoloc s, t)) stl in
  Psig_type stl
;

value ocaml_psig_value s vd = Psig_value (mknoloc s) vd;

value ocaml_pstr_class_type =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSE Some (fun ctl -> Pstr_class_type ctl) END
;

value ocaml_pstr_exception s ed = Pstr_exception (mknoloc s) ed;

value ocaml_pstr_exn_rebind =
  IFDEF OCAML_VERSION <= OCAML_2_99 THEN None
  ELSE Some (fun s li -> Pstr_exn_rebind (mknoloc s) (mknoloc li)) END
;

value ocaml_pstr_include =
  IFDEF OCAML_VERSION <= OCAML_3_00 THEN None
  ELSE Some (fun me -> Pstr_include me) END
;

value ocaml_pstr_modtype s mt = Pstr_modtype (mknoloc s) mt;

value ocaml_pstr_module s me = Pstr_module (mknoloc s) me;

value ocaml_pstr_open li =
  IFDEF OCAML_VERSION < OCAML_4_01 THEN Pstr_open (mknoloc li)
  ELSE Pstr_open Fresh (mknoloc li) END
;

value ocaml_pstr_primitive s vd = Pstr_primitive (mknoloc s) vd;

value ocaml_pstr_recmodule =
  IFDEF OCAML_VERSION <= OCAML_3_06 THEN None
  ELSIFDEF OCAML_VERSION < OCAML_4_00 THEN
    Some (fun nel -> Pstr_recmodule nel)
  ELSE
    let f nel =
      Pstr_recmodule (List.map (fun (s, mt, me) → (mknoloc s, mt, me)) nel)
    in
    Some f
  END
;

value ocaml_pstr_type stl = 
  IFDEF OCAML_VERSION < OCAML_4_00 THEN Pstr_type stl
  ELSE
    let stl = List.map (fun (s, t) → (mknoloc s, t)) stl in
    Pstr_type stl
  END
;

value ocaml_class_infos =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSIFDEF OCAML_VERSION <= OCAML_3_00 THEN
    Some
      (fun virt params name expr loc variance ->
         {pci_virt = virt; pci_params = params; pci_name = name;
          pci_expr = expr; pci_loc = loc})
  ELSE
    Some
      (fun virt (sl, sloc) name expr loc variance ->
        let params = (List.map (fun s → mkloc loc s) sl, sloc) in
        {pci_virt = virt; pci_params = params; pci_name = mkloc loc name;
         pci_expr = expr; pci_loc = loc; pci_variance = variance})
  END
;

value ocaml_pmod_ident li = Pmod_ident (mknoloc li);

value ocaml_pmod_functor s mt me =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN Pmod_functor (mknoloc s) mt me
  ELSE Pmod_functor (mknoloc s) (Some mt) me END
;

value ocaml_pmod_unpack =
  IFDEF OCAML_VERSION < OCAML_3_12 THEN None
  ELSIFDEF OCAML_VERSION < OCAML_3_13_0 THEN
    Some (Left (fun e pt -> Pmod_unpack e pt))
  ELSE
    (Some (Right (fun e -> Pmod_unpack e, fun pt -> Ptyp_package pt)) :
     option (choice ('a -> 'b -> 'c) 'd))
  END
;

value ocaml_pcf_cstr =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSIFDEF OCAML_VERSION < OCAML_4_00 THEN
    Some (fun (t1, t2, loc) -> Pcf_cstr (t1, t2, loc))
  ELSE Some (fun (t1, t2, loc) -> Pcf_constr (t1, t2)) END
;

value ocaml_pcf_inher =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN
    fun (id, cl, el, loc) pb -> Pcf_inher (id, cl, el, pb, loc)
  ELSIFDEF OCAML_VERSION >= OCAML_3_12 THEN
    fun ce pb -> Pcf_inher Fresh ce pb
  ELSE
    fun ce pb -> Pcf_inher ce pb
  END
;

value ocaml_pcf_init =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSE Some (fun e -> Pcf_init e) END
;

value ocaml_pcf_meth (s, pf, ovf, e, loc) =
  let pf = if pf then Private else Public in
  IFDEF OCAML_VERSION >= OCAML_3_12 THEN
    let ovf = if ovf then Override else Fresh in
    IFDEF OCAML_VERSION < OCAML_4_00 THEN Pcf_meth (s, pf, ovf, e, loc)
    ELSE Pcf_meth (mkloc loc s, pf, ovf, e) END
  ELSE Pcf_meth (s, pf, e, loc) END
;

value ocaml_pcf_val (s, mf, ovf, e, loc) =
  let mf = if mf then Mutable else Immutable in
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN Pcf_val (s, Public, mf, Some e, loc)
  ELSIFDEF OCAML_VERSION >= OCAML_3_12 THEN
    let ovf = if ovf then Override else Fresh in
    IFDEF OCAML_VERSION < OCAML_4_00 THEN Pcf_val (s, mf, ovf, e, loc)
    ELSE Pcf_val (mkloc loc s, mf, ovf, e) END
  ELSE Pcf_val (s, mf, e,  loc) END
;

value ocaml_pcf_valvirt =
  IFDEF OCAML_VERSION < OCAML_3_10_0 THEN None
  ELSE
    let ocaml_pcf (s, mf, t, loc) =
      let mf = if mf then Mutable else Immutable in
      IFDEF OCAML_VERSION < OCAML_4_00 THEN Pcf_valvirt (s, mf, t, loc)
      ELSE Pcf_valvirt (mkloc loc s, mf, t) END
    in
    Some ocaml_pcf
  END
;

value ocaml_pcf_virt (s, pf, t, loc) =
  IFDEF OCAML_VERSION < OCAML_4_00 THEN Pcf_virt (s, pf, t, loc)
  ELSE Pcf_virt (mkloc loc s, pf, t) END
;

value ocaml_pcl_apply =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSIFDEF OCAML_VERSION <= OCAML_2_04 THEN
    Some (fun ce lel -> Pcl_apply ce (List.map snd lel))
  ELSE
    Some (fun ce lel -> Pcl_apply ce lel)
  END
;

value ocaml_pcl_constr =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSE Some (fun li ctl -> Pcl_constr (mknoloc li) ctl) END
;

value ocaml_pcl_constraint =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSE Some (fun ce ct -> Pcl_constraint ce ct) END
;

value ocaml_pcl_fun =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN
    None
  ELSIFDEF OCAML_VERSION <= OCAML_2_04 THEN
    Some (fun lab ceo p ce -> Pcl_fun p ce)
  ELSE
    Some (fun lab ceo p ce -> Pcl_fun lab ceo p ce)
  END
;

value ocaml_pcl_let =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSE Some (fun rf pel ce -> Pcl_let rf pel ce) END
;

value ocaml_pcl_structure =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSE Some (fun cs -> Pcl_structure cs) END
;

value ocaml_pctf_cstr =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSIFDEF OCAML_VERSION < OCAML_4_00 THEN
    Some (fun (t1, t2, loc) -> Pctf_cstr (t1, t2, loc))
  ELSE
    Some (fun (t1, t2, loc) -> Pctf_cstr (t1, t2)) END
;

value ocaml_pctf_meth (s, pf, t, loc) =
  IFDEF OCAML_VERSION < OCAML_4_00 THEN Pctf_meth (s, pf, t, loc)
  ELSE Pctf_meth (s, pf, t) END
;

value ocaml_pctf_val (s, mf, t, loc) =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN Pctf_val (s, Public, mf, Some t, loc)
  ELSIFDEF OCAML_VERSION < OCAML_3_10 THEN Pctf_val (s, mf, Some t, loc)
  ELSIFDEF OCAML_VERSION < OCAML_4_00 THEN Pctf_val (s, mf, Concrete, t, loc)
  ELSE Pctf_val (s, mf, Concrete, t) END
;

value ocaml_pctf_virt (s, pf, t, loc) =
  IFDEF OCAML_VERSION < OCAML_4_00 THEN Pctf_virt (s, pf, t, loc)
  ELSE Pctf_virt (s, pf, t) END
;

value ocaml_pcty_constr =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSE Some (fun li ltl -> Pcty_constr (mknoloc li) ltl) END
;

value ocaml_pcty_fun =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN
    None
  ELSIFDEF OCAML_VERSION <= OCAML_2_04 THEN
    Some (fun lab t ct -> Pcty_fun t ct)
  ELSE
    Some (fun lab t ct -> Pcty_fun lab t ct) END
;

value ocaml_pcty_signature =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN None
  ELSIFDEF OCAML_VERSION < OCAML_4_00 THEN
    Some (fun (t, cil) -> Pcty_signature (t, cil))
  ELSE
    let f (t, ctfl) =
      let cs =
        {pcsig_self = t; pcsig_fields = ctfl; pcsig_loc = t.ptyp_loc}
      in
      Pcty_signature cs
    in
    Some f
  END
;

value ocaml_pdir_bool =
  IFDEF OCAML_VERSION <= OCAML_2_04 THEN None
  ELSE Some (fun b -> Pdir_bool b) END
;

value ocaml_pwith_modsubst =
  IFDEF OCAML_VERSION < OCAML_3_12_0 THEN None
  ELSE Some (fun loc me -> Pwith_modsubst (mkloc loc me)) END
;

value ocaml_pwith_type loc (i, td) =
  IFDEF OCAML_VERSION < OCAML_4_02_0 THEN Pwith_type td
  ELSE Pwith_type (mkloc loc (Lident i), td) END
;

value ocaml_pwith_module loc me = Pwith_module (mkloc loc me);

value ocaml_pwith_typesubst =
  IFDEF OCAML_VERSION < OCAML_3_12_0 THEN None
  ELSE Some (fun td -> Pwith_typesubst td) END
;

value module_prefix_can_be_in_first_record_label_only =
  IFDEF OCAML_VERSION <= OCAML_3_07 THEN False ELSE True END
;

value split_or_patterns_with_bindings =
  IFDEF OCAML_VERSION <= OCAML_3_01 THEN True ELSE False END
;

value has_records_with_with =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN False ELSE True END
;

IFDEF JOCAML THEN
  value joinclause (loc, jc) =
    let jc =
      List.map
        (fun (loc, (jpl, e)) ->
           let jpl =
             List.map
               (fun (locp, (loci, s), p) ->
                  let ji = {pjident_desc = s; pjident_loc = loci} in
                  {pjpat_desc = (ji, p); pjpat_loc = locp})
               jpl
           in
           {pjclause_desc = (jpl, e); pjclause_loc = loc})
        jc
    in
    {pjauto_desc = jc; pjauto_loc = loc}
  ;
END;

value jocaml_pstr_def =
  IFDEF JOCAML THEN Some (fun jcl -> Pstr_def (List.map joinclause jcl))
  ELSE (None : option (_ -> _)) END
;

value jocaml_pexp_def =
  IFDEF JOCAML THEN Some (fun jcl e -> Pexp_def (List.map joinclause jcl) e)
  ELSE (None : option (_ -> _ -> _)) END
;

value jocaml_pexp_par =
  IFDEF JOCAML THEN Some (fun e1 e2 -> Pexp_par e1 e2)
  ELSE (None : option (_ -> _ -> _)) END
;

value jocaml_pexp_reply =
  IFDEF JOCAML THEN
    let pexp_reply loc e (sloc, s) =
      let ji = {pjident_desc = s; pjident_loc = sloc} in
      Pexp_reply e ji
    in
    Some pexp_reply
  ELSE (None : option (_ -> _ -> _ -> _)) END
;

value jocaml_pexp_spawn =
  IFDEF JOCAML THEN Some (fun e -> Pexp_spawn e)
  ELSE (None : option (_ -> _)) END
;

value arg_rest =
  fun
  [ IFDEF OCAML_VERSION >= OCAML_2_00 THEN Arg.Rest r -> Some r END
  | _ -> None ]
;

value arg_set_string =
  fun
  [ IFDEF OCAML_VERSION >= OCAML_3_07 THEN Arg.Set_string r -> Some r END
  | _ -> None ]
;

value arg_set_int =
  fun
  [ IFDEF OCAML_VERSION >= OCAML_3_07 THEN Arg.Set_int r -> Some r END
  | _ -> None ]
;

value arg_set_float =
  fun
  [ IFDEF OCAML_VERSION >= OCAML_3_07 THEN Arg.Set_float r -> Some r END
  | _ -> None ]
;

value arg_symbol =
  fun
  [ IFDEF OCAML_VERSION >= OCAML_3_07 THEN Arg.Symbol s f -> Some (s, f) END
  | _ -> None ]
;

value arg_tuple =
  fun
  [ IFDEF OCAML_VERSION >= OCAML_3_07 THEN Arg.Tuple t -> Some t END
  | _ -> None ]
;

value arg_bool =
  fun
  [ IFDEF OCAML_VERSION >= OCAML_3_07 THEN Arg.Bool f -> Some f END
  | _ -> None ]
;

value char_escaped =
  IFDEF OCAML_VERSION >= OCAML_3_11 THEN Char.escaped
  ELSE
    fun
    [ '\r' -> "\\r"
    | c -> Char.escaped c ]
  END
;

value hashtbl_mem =
  IFDEF OCAML_VERSION <= OCAML_2_01 THEN
    fun ht a ->
      try let _ = Hashtbl.find ht a in True with [ Not_found -> False ]
  ELSE
    Hashtbl.mem
  END
;

IFDEF OCAML_VERSION <= OCAML_1_07 THEN
  value rec list_rev_append l1 l2 =
    match l1 with
    [ [x :: l] -> list_rev_append l [x :: l2]
    | [] -> l2 ]
  ;
ELSE
  value list_rev_append = List.rev_append;
END;

value list_rev_map =
  IFDEF OCAML_VERSION <= OCAML_2_02 THEN
    fun f ->
      loop [] where rec loop r =
        fun
        [ [x :: l] -> loop [f x :: r] l
        | [] -> r ]
  ELSE
    List.rev_map
  END
;

value list_sort =
  IFDEF OCAML_VERSION <= OCAML_2_99 THEN
    fun f l -> Sort.list (fun x y -> f x y <= 0) l
  ELSE List.sort END
;

value pervasives_set_binary_mode_out =
  IFDEF OCAML_VERSION <= OCAML_1_07 THEN fun _ _ -> ()
  ELSE Pervasives.set_binary_mode_out END
;

IFDEF OCAML_VERSION <= OCAML_3_04 THEN
  declare
    value scan_format fmt i kont =
      match fmt.[i+1] with
      [ 'c' -> Obj.magic (fun (c : char) -> kont (String.make 1 c) (i + 2))
      | 'd' -> Obj.magic (fun (d : int) -> kont (string_of_int d) (i + 2))
      | 's' -> Obj.magic (fun (s : string) -> kont s (i + 2))
      | c ->
          failwith
            (Printf.sprintf "Pretty.sprintf \"%s\" '%%%c' not impl" fmt c) ]
    ;
    value printf_ksprintf kont fmt =
      let fmt = (Obj.magic fmt : string) in
      let len = String.length fmt in
      doprn [] 0 where rec doprn rev_sl i =
        if i >= len then do {
          let s = String.concat "" (List.rev rev_sl) in
          Obj.magic (kont s)
        }
        else do {
          match fmt.[i] with
          [ '%' -> scan_format fmt i (fun s -> doprn [s :: rev_sl])
          | c -> doprn [String.make 1 c :: rev_sl] (i + 1)  ]
        }
    ;
  end;
ELSIFDEF OCAML_VERSION <= OCAML_3_08_4 THEN
  value printf_ksprintf = Printf.kprintf;
ELSE
  value printf_ksprintf = Printf.ksprintf;
END;

value string_contains =
  IFDEF OCAML_VERSION <= OCAML_2_00 THEN
    fun s c ->
      loop 0 where rec loop i =
        if i = String.length s then False
        else if s.[i] = c then True
        else loop (i + 1)
  ELSIFDEF OCAML_2_01 THEN
    fun s c -> s <> "" && String.contains s c
  ELSE
    String.contains
  END
;
