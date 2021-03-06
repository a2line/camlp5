(* camlp5r *)
(* extfun.ml,v *)
(* Copyright (c) INRIA 2007-2016 *)

(* Extensible Functions *)

type ('a, 'b) t = ('a, 'b) matching list
and ('a, 'b) matching = { patt : patt; has_when : bool; expr : ('a, 'b) expr }
and patt =
    Eapp of patt list
  | Eacc of patt list
  | Econ of string
  | Estr of string
  | Eint of string
  | Etup of patt list
  | Evar of unit
and ('a, 'b) expr = 'a -> 'b option;;

exception Failure;;

let empty = [];;

(*** Apply ***)

let rec apply_matchings a =
  function
    m :: ml ->
      begin match m.expr a with
        None -> apply_matchings a ml
      | x -> x
      end
  | [] -> None
;;

let apply ef a =
  match apply_matchings a ef with
    Some x -> x
  | None -> raise Failure
;;

(*** Trace ***)

let rec list_iter_sep f s =
  function
    [] -> ()
  | [x] -> f x
  | x :: l -> f x; s (); list_iter_sep f s l
;;

let rec print_patt =
  function
    Eapp pl -> list_iter_sep print_patt2 (fun () -> print_string " ") pl
  | p -> print_patt2 p
and print_patt2 =
  function
    Eacc pl -> list_iter_sep print_patt1 (fun () -> print_string ".") pl
  | p -> print_patt1 p
and print_patt1 =
  function
    Econ s -> print_string s
  | Estr s -> print_string "\""; print_string s; print_string "\""
  | Eint s -> print_string s
  | Evar () -> print_string "_"
  | Etup pl ->
      print_string "(";
      list_iter_sep print_patt (fun () -> print_string ", ") pl;
      print_string ")"
  | Eapp _ | Eacc _ as p -> print_string "("; print_patt p; print_string ")"
;;

let print ef =
  List.iter
    (fun m ->
       print_patt m.patt;
       if m.has_when then print_string " when ...";
       print_newline ())
    ef
;;

(*** Extension ***)

let compare_patt p1 p2 =
  match p1, p2 with
    Evar _, _ -> 1
  | _, Evar _ -> -1
  | _ -> compare p1 p2
;;

let insert_matching matchings (patt, has_when, expr) =
  let m1 = {patt = patt; has_when = has_when; expr = expr} in
  let rec loop =
    function
      m :: ml as gml ->
        if m1.has_when && not m.has_when then m1 :: gml
        else if not m1.has_when && m.has_when then m :: loop ml
        else
          let c = compare_patt m1.patt m.patt in
          if c < 0 then m1 :: gml
          else if c > 0 then m :: loop ml
          else if m.has_when then m1 :: gml
          else m1 :: ml
    | [] -> [m1]
  in
  loop matchings
;;

(* available extension function *)

let extend ef matchings_def =
  List.fold_left insert_matching ef matchings_def
;;
