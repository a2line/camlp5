(* camlp5r *)
(* diff.ml,v *)
(* Copyright (c) INRIA 2007-2016 *)

(* Parts of Code of GNU diff (analyze.c) translated from C to OCaml
   and adjusted. Basic algorithm described by Eugene W.Myers in:
     "An O(ND) Difference Algorithm and Its Variations" *)

open Versdep;

exception DiagReturn of int;

value diag fd bd sh xv yv xoff xlim yoff ylim = do {
  let dmin = xoff - ylim in
  let dmax = xlim - yoff in
  let fmid = xoff - yoff in
  let bmid = xlim - ylim in
  let odd = (fmid - bmid) land 1 <> 0 in
  fd.(sh+fmid) := xoff;
  bd.(sh+bmid) := xlim;
  try
    loop fmid fmid bmid bmid where rec loop fmin fmax bmin bmax = do {
      let fmin =
        if fmin > dmin then do { fd.(sh+fmin-2) := -1; fmin - 1 }
        else fmin + 1
      in
      let fmax =
        if fmax < dmax then do { fd.(sh+fmax+2) := -1; fmax + 1 }
        else fmax - 1
      in
      loop fmax where rec loop d =
        if d < fmin then ()
        else do {
          let tlo = fd.(sh+d-1) in
          let thi = fd.(sh+d+1) in
          let x = if tlo >= thi then tlo + 1 else thi in
          let x =
            loop xv yv xlim ylim x (x - d)
            where rec loop xv yv xlim ylim x y =
              if x < xlim && y < ylim && xv x == yv y then
                loop xv yv xlim ylim (x + 1) (y + 1)
              else x
          in
          fd.(sh+d) := x;
          if odd && bmin <= d && d <= bmax && bd.(sh+d) <= fd.(sh+d) then
            raise (DiagReturn d)
          else loop (d - 2)
        };
      let bmin =
        if bmin > dmin then do { bd.(sh+bmin-2) := max_int; bmin - 1 }
        else bmin + 1
      in
      let bmax =
        if bmax < dmax then do { bd.(sh+bmax+2) := max_int; bmax + 1 }
        else bmax - 1
      in
      loop bmax where rec loop d =
        if d < bmin then ()
        else do {
          let tlo = bd.(sh+d-1) in
          let thi = bd.(sh+d+1) in
          let x = if tlo < thi then tlo else thi - 1 in
          let x =
            loop xv yv xoff yoff x (x - d)
            where rec loop xv yv xoff yoff x y =
              if x > xoff && y > yoff && xv (x - 1) == yv (y - 1) then
                loop xv yv xoff yoff (x - 1) (y - 1)
              else x
          in
          bd.(sh+d) := x;
          if not odd && fmin <= d && d <= fmax && bd.(sh+d) <= fd.(sh+d) then
            raise (DiagReturn d)
          else loop (d - 2)
        };
      loop fmin fmax bmin bmax
    }
  with
  [ DiagReturn i -> i ]
};

value diff_loop a ai b bi n m = do {
  let fd = Array.make (n + m + 3) 0 in
  let bd = Array.make (n + m + 3) 0 in
  let sh = m + 1 in
  let xvec i = a.(ai.(i)) in
  let yvec j = b.(bi.(j)) in
  let chng1 = Array.make (Array.length a) True in
  let chng2 = Array.make (Array.length b) True in
  for i = 0 to n - 1 do { chng1.(ai.(i)) := False };
  for j = 0 to m - 1 do { chng2.(bi.(j)) := False };
  let rec loop xoff xlim yoff ylim =
    let (xoff, yoff) =
      loop xoff yoff where rec loop xoff yoff =
        if xoff < xlim && yoff < ylim && xvec xoff == yvec yoff then
          loop (xoff + 1) (yoff + 1)
        else (xoff, yoff)
    in
    let (xlim, ylim) =
      loop xlim ylim where rec loop xlim ylim =
        if xlim > xoff && ylim > yoff && xvec (xlim - 1) == yvec (ylim - 1)
        then
          loop (xlim - 1) (ylim - 1)
        else (xlim, ylim)
    in
    if xoff = xlim then for y = yoff to ylim - 1 do { chng2.(bi.(y)) := True }
    else if yoff = ylim then
      for x = xoff to xlim - 1 do { chng1.(ai.(x)) := True }
    else do {
      let d = diag fd bd sh xvec yvec xoff xlim yoff ylim in
      let b = bd.(sh+d) in
      loop xoff b yoff (b - d);
      loop b xlim (b - d) ylim
    }
  in
  loop 0 n 0 m;
  (chng1, chng2)
};

(* [make_indexer a b] returns an array of index of items of [a] which
   are also present in [b]; this way, the main algorithm can skip items
   which, anyway, are different. This improves the speed much.
     The same time, this function updates the items of so that all
   equal items point to the same unique item. All items comparisons in
   the main algorithm can therefore be done with [==] instead of [=],
   what can improve speed much. *)
value make_indexer a b = do {
  let n = Array.length a in
  let htb = Hashtbl.create (10 * Array.length b) in
  Array.iteri
    (fun i e ->
       try b.(i) := Hashtbl.find htb e with
       [ Not_found -> Hashtbl.add htb e e ])
    b;
  let ai = array_create n 0 in
  let k =
    loop 0 0 where rec loop i k =
      if i = n then k
      else
        let k =
          try do {
            a.(i) := Hashtbl.find htb a.(i);
            (* line found (since "Not_found" not raised) *)
            ai.(k) := i;
            k + 1
          }
          with
          [ Not_found -> k ]
        in
        loop (i + 1) k
  in
  Array.sub ai 0 k
};

value f a b =
  let ai = make_indexer a b in
  let bi = make_indexer b a in
  let n = Array.length ai in
  let m = Array.length bi in
  diff_loop a ai b bi n m
;
