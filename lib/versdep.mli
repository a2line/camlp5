(* camlp5r *)
(* $Id: versdep.mli,v 1.7 2010/08/31 15:37:29 deraugla Exp $ *)
(* Copyright (c) INRIA 2007-2010 *)

open Parsetree;
open Asttypes;

type choice 'a 'b =
  [ Left of 'a
  | Right of 'b ]
;

value sys_ocaml_version : string;

value ocaml_location : (string * int * int * int * int) -> Location.t;

value ocaml_ptyp_poly : option (list string -> core_type -> core_type_desc);
value ocaml_type_declaration :
  list string -> list (core_type * core_type * Location.t) -> type_kind ->
    private_flag -> option core_type -> Location.t -> list (bool * bool) ->
    type_declaration;
value ocaml_ptype_record :
  list (string * mutable_flag * core_type * Location.t) -> private_flag ->
    type_kind;

value ocaml_ptype_variant :
  list (string * list core_type * Location.t) -> private_flag -> type_kind;
value ocaml_ptyp_arrow : string -> core_type -> core_type -> core_type_desc;
value ocaml_ptyp_variant :
  list (choice (string * bool * list core_type) core_type) -> bool ->
    option (list string) -> option core_type_desc;
value ocaml_ptyp_class :
  Longident.t -> list core_type -> list string -> core_type_desc;
value ocaml_ptype_private : type_kind;
value ocaml_class_infos :
  virtual_flag -> (list string * Location.t) -> string -> 'a -> Location.t ->
    list (bool * bool) -> class_infos 'a;

value module_prefix_can_be_in_first_record_label_only : bool;
value split_or_patterns_with_bindings : bool;

value ocaml_pexp_assertfalse : string -> Location.t -> expression_desc;
value ocaml_pexp_assert :
  string -> Location.t -> expression -> expression_desc;

value ocaml_pexp_function :
  string -> option expression -> list (pattern * expression) ->
    expression_desc;
value ocaml_pexp_apply :
  expression -> list (string * expression) -> expression_desc;
value ocaml_pexp_lazy : option (expression -> expression_desc);
value ocaml_const_int32 : option (string -> constant);
value ocaml_const_int64 : option (string -> constant);
value ocaml_const_nativeint : option (string -> constant);
value ocaml_pexp_object : option (class_structure -> expression_desc);
value ocaml_pexp_variant :
  option
    (expression_desc -> option (string * option expression) *
     (string * option expression) -> expression_desc);

value ocaml_ppat_lazy : option (pattern -> pattern_desc);
value ocaml_ppat_record : list (Longident.t * pattern) -> pattern_desc;
value ocaml_ppat_type : option (Longident.t -> pattern_desc);
value ocaml_ppat_variant :
  option
    (pattern_desc -> option (string * option pattern) *
     (string * option pattern) -> pattern_desc);

value ocaml_psig_recmodule :
  option (list (string * module_type) -> signature_item_desc);

value ocaml_pstr_exn_rebind :
  option (string -> Longident.t -> structure_item_desc);
value ocaml_pstr_include : option (module_expr -> structure_item_desc);
value ocaml_pstr_recmodule :
  option (list (string * module_type * module_expr) -> structure_item_desc);

value ocaml_pctf_val :
  (string * mutable_flag * core_type * Location.t) -> class_type_field;
value ocaml_pcty_fun : (string * core_type * class_type) -> class_type_desc;

value ocaml_pcl_fun :
  (string * option expression * pattern * class_expr) -> class_expr_desc;
value ocaml_pcl_apply :
  (class_expr * list (string * expression)) -> class_expr_desc;

value ocaml_pcf_inher : class_expr -> option string -> class_field;
value ocaml_pcf_meth :
  (string * private_flag * expression * Location.t) -> class_field;
value ocaml_pcf_val :
  (string * mutable_flag * expression * Location.t) -> class_field;
value ocaml_pexp_poly :
  option (expression -> option core_type -> expression_desc);

value ocaml_pdir_bool : option (bool -> directive_argument);

value arg_set_string : Arg.spec -> option (ref string);
value arg_set_int : Arg.spec -> option (ref int);
value arg_set_float : Arg.spec -> option (ref float);
value arg_symbol : Arg.spec -> option (list string * string -> unit);
value arg_tuple : Arg.spec -> option (list Arg.spec);
value arg_bool : Arg.spec -> option (bool -> unit);

value printf_ksprintf : (string -> string) -> format 'a unit string -> 'a;
