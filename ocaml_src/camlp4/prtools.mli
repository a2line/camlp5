(* camlp4r *)
(* This file has been generated by program: do not edit! *)
(* Copyright (c) INRIA 2007 *)

open Pcaml.NewPrinter;;

type ('a, 'b) pr_gfun = pr_ctx -> string -> 'a -> 'b -> string;;

val shi : pr_ctx -> int -> pr_ctx;;
val tab : pr_ctx -> string;;

val hlist : 'a pr_fun -> 'a list pr_fun;;
   (** horizontal list
       [hlist elem ctx b e k] returns the horizontally pretty printed
       string of a list of elements; elements are separated with spaces.
       The list is displayed in one only line. If this function is called
       in the context of the [horiz] function of the function [horiz_vertic]
       of the module Sformat, and if the line overflows or contains newlines,
       the function fails (the exception is catched by [horiz_vertic] for
       a vertical pretty print). *)
val hlist2 :
  ('a, 'b) pr_gfun -> ('a, 'b) pr_gfun -> ('a list, ('b * 'b)) pr_gfun;;
   (** horizontal list with different function from 2nd element on *)
val hlistl : 'a pr_fun -> 'a pr_fun -> 'a list pr_fun;;
   (** horizontal list with different function for the last element *)

val vlist : 'a pr_fun -> 'a list pr_fun;;
   (** vertical list
       [vlist elem ctx b e k] returns the vertically pretty printed
       string of a list of elements; elements are separated with newlines
       and indentations. *)
val vlist2 :
  ('a, 'b) pr_gfun -> ('a, 'b) pr_gfun -> ('a list, ('b * 'b)) pr_gfun;;
   (** vertical list with different function from 2nd element on *)
val vlistl : 'a pr_fun -> 'a pr_fun -> 'a list pr_fun;;
   (** vertical list with different function for the last element *)

val plist : 'a pr_fun -> int -> ('a * string) list pr_fun;;
   (** paragraph list
       [plist elem sh ctx b el k] returns the pretty printed string of
       a list of elements with separators. The elements are printed
       horizontally as far as possible. When an element does not fit
       on the line, a newline is added and the element is displayed
       in the next line with an indentation of [sh]. [elem] is the
       function to print elements, [ctx] is the context, [b] the
       beginning of the line, [el] a list of pairs (element * separator)
       (the last separator is ignored), and [k] the end of the line *)
val plistl : 'a pr_fun -> 'a pr_fun -> int -> ('a * string) list pr_fun;;
   (** paragraph list with a different function for the last element *)

val source : string ref;;
val comm_bef : pr_ctx -> MLast.loc -> string;;