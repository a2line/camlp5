(* camlp5r *)
(* extfold.ml,v *)
(* Copyright (c) INRIA 2007-2016 *)

type ('te, 'a, 'b) t =
  'te Gramext.g_entry -> 'te Gramext.g_symbol list -> ('te Stream.t -> 'a) ->
    'te Stream.t -> 'b
;;

type ('te, 'a, 'b) tsep =
  'te Gramext.g_entry -> 'te Gramext.g_symbol list -> ('te Stream.t -> 'a) ->
    ('te Stream.t -> unit) -> 'te Stream.t -> 'b
;;

let gen_fold0 final f e entry symbl psymb =
  let rec fold accu (strm__ : _ Stream.t) =
    match try Some (psymb strm__) with Stream.Failure -> None with
      Some a -> fold (f a accu) strm__
    | _ -> accu
  in
  fun (strm__ : _ Stream.t) -> let a = fold e strm__ in final a
;;

let gen_fold1 final f e entry symbl psymb =
  let rec fold accu (strm__ : _ Stream.t) =
    match try Some (psymb strm__) with Stream.Failure -> None with
      Some a -> fold (f a accu) strm__
    | _ -> accu
  in
  fun (strm__ : _ Stream.t) ->
    let a = psymb strm__ in
    let a =
      try fold (f a e) strm__ with Stream.Failure -> raise (Stream.Error "")
    in
    final a
;;

let gen_fold0sep final f e entry symbl psymb psep =
  let failed =
    function
      [symb; sep] -> Grammar.symb_failed_txt entry sep symb
    | _ -> "failed"
  in
  let rec kont accu (strm__ : _ Stream.t) =
    match try Some (psep strm__) with Stream.Failure -> None with
      Some v ->
        let a =
          try psymb strm__ with
            Stream.Failure -> raise (Stream.Error (failed symbl))
        in
        kont (f a accu) strm__
    | _ -> accu
  in
  fun (strm__ : _ Stream.t) ->
    match try Some (psymb strm__) with Stream.Failure -> None with
      Some a -> let a = kont (f a e) strm__ in final a
    | _ -> e
;;

let gen_fold1sep final f e entry symbl psymb psep =
  let failed =
    function
      [symb; sep] -> Grammar.symb_failed_txt entry sep symb
    | _ -> "failed"
  in
  let parse_top =
    function
      [symb; _] -> Grammar.parse_top_symb entry symb
    | _ -> raise Stream.Failure
  in
  let rec kont accu (strm__ : _ Stream.t) =
    match try Some (psep strm__) with Stream.Failure -> None with
      Some v ->
        let a =
          try
            try psymb strm__ with
              Stream.Failure ->
                let a =
                  try parse_top symbl strm__ with
                    Stream.Failure -> raise (Stream.Error (failed symbl))
                in
                Obj.magic a
          with Stream.Failure -> raise (Stream.Error "")
        in
        kont (f a accu) strm__
    | _ -> accu
  in
  fun (strm__ : _ Stream.t) ->
    let a = psymb strm__ in let a = kont (f a e) strm__ in final a
;;

let sfold0 f e = gen_fold0 (fun x -> x) f e;;
let sfold1 f e = gen_fold1 (fun x -> x) f e;;
let sfold0sep f e = gen_fold0sep (fun x -> x) f e;;
let sfold1sep f e = gen_fold1sep (fun x -> x) f e;;

let cons x y = x :: y;;
let nil = [];;

let slist0 entry = gen_fold0 List.rev cons nil entry;;
let slist1 entry = gen_fold1 List.rev cons nil entry;;
let slist0sep entry = gen_fold0sep List.rev cons nil entry;;
let slist1sep entry = gen_fold1sep List.rev cons nil entry;;

let sopt entry symbl psymb (strm__ : _ Stream.t) =
  try Some (psymb strm__) with Stream.Failure -> None
;;
