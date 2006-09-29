(* camlp4r q_MLast.cmo *)
(* This file has been generated by program: do not edit! *)

open Printf;;

let action_arg s sl =
  function
    Arg.Unit f -> if s = "" then begin f (); Some sl end else None
  | Arg.Set r -> if s = "" then begin r := true; Some sl end else None
  | Arg.Clear r -> if s = "" then begin r := false; Some sl end else None
  | Arg.Rest f -> List.iter f (s :: sl); Some []
  | Arg.String f ->
      if s = "" then
        match sl with
          s :: sl -> f s; Some sl
        | [] -> None
      else begin f s; Some sl end
  | Arg.Set_string r ->
      if s = "" then
        match sl with
          s :: sl -> r := s; Some sl
        | [] -> None
      else begin r := s; Some sl end
  | Arg.Int f ->
      if s = "" then
        match sl with
          s :: sl ->
            begin try f (int_of_string s); Some sl with
              Failure "int_of_string" -> None
            end
        | [] -> None
      else
        begin try f (int_of_string s); Some sl with
          Failure "int_of_string" -> None
        end
  | Arg.Set_int r ->
      if s = "" then
        match sl with
          s :: sl ->
            begin try r := int_of_string s; Some sl with
              Failure "int_of_string" -> None
            end
        | [] -> None
      else
        begin try r := int_of_string s; Some sl with
          Failure "int_of_string" -> None
        end
  | Arg.Float f ->
      if s = "" then
        match sl with
          s :: sl -> f (float_of_string s); Some sl
        | [] -> None
      else begin f (float_of_string s); Some sl end
  | Arg.Set_float r ->
      if s = "" then
        match sl with
          s :: sl -> r := float_of_string s; Some sl
        | [] -> None
      else begin r := float_of_string s; Some sl end
  | Arg.Symbol (syms, f) ->
      begin match if s = "" then sl else s :: sl with
        s :: sl when List.mem s syms -> f s; Some sl
      | _ -> None
      end
  | Arg.Tuple _ -> failwith "Arg.Tuple not implemented"
  | Arg.Bool _ -> failwith "Arg.Bool not implemented"
;;

let common_start s1 s2 =
  let rec loop i =
    if i == String.length s1 || i == String.length s2 then i
    else if s1.[i] == s2.[i] then loop (i + 1)
    else i
  in
  loop 0
;;

let rec parse_arg s sl =
  function
    (name, action, _) :: spec_list ->
      let i = common_start s name in
      if i == String.length name then
        try action_arg (String.sub s i (String.length s - i)) sl action with
          Arg.Bad _ -> parse_arg s sl spec_list
      else parse_arg s sl spec_list
  | [] -> None
;;

let rec parse_aux spec_list anon_fun =
  function
    [] -> []
  | s :: sl ->
      if String.length s > 1 && s.[0] = '-' then
        match parse_arg s sl spec_list with
          Some sl -> parse_aux spec_list anon_fun sl
        | None -> s :: parse_aux spec_list anon_fun sl
      else begin (anon_fun s : unit); parse_aux spec_list anon_fun sl end
;;

let loc_fmt =
  match Sys.os_type with
    "MacOS" ->
      format_of_string "File \"%s\"; line %d; characters %d to %d\n### "
  | _ -> format_of_string "File \"%s\", line %d, characters %d-%d:\n"
;;

let print_location loc =
  if !(Pcaml.input_file) <> "-" then
    let (fname, line, bp, ep) = Stdpp.line_of_loc !(Pcaml.input_file) loc in
    eprintf loc_fmt fname line bp ep
  else eprintf "At location %d-%d\n" (fst loc) (snd loc)
;;

let print_warning loc s = print_location loc; eprintf "Warning: %s\n" s;;

let rec parse_file pa getdir useast =
  let name = !(Pcaml.input_file) in
  Pcaml.warning := print_warning;
  let ic = if name = "-" then stdin else open_in_bin name in
  let cs = Stream.of_channel ic in
  let clear () = if name = "-" then () else close_in ic in
  let phr =
    try
      let rec loop () =
        let (pl, stopped_at_directive) = pa cs in
        if stopped_at_directive then
          let pl =
            let rpl = List.rev pl in
            match getdir rpl with
              Some x ->
                begin match x with
                  loc, "load", Some (MLast.ExStr (_, s)) ->
                    Odyl_main.loadfile s; pl
                | loc, "directory", Some (MLast.ExStr (_, s)) ->
                    Odyl_main.directory s; pl
                | loc, "use", Some (MLast.ExStr (_, s)) ->
                    List.rev_append rpl
                      [useast loc s (use_file pa getdir useast s), loc]
                | loc, _, _ ->
                    Stdpp.raise_with_loc loc (Stream.Error "bad directive")
                end
            | None -> pl
          in
          pl @ loop ()
        else pl
      in
      loop ()
    with
      x -> clear (); raise x
  in
  clear (); phr
and use_file pa getdir useast s =
  let clear =
    let v_input_file = !(Pcaml.input_file) in
    fun () -> Pcaml.input_file := v_input_file
  in
  Pcaml.input_file := s;
  try let r = parse_file pa getdir useast in clear (); r with
    e -> clear (); raise e
;;

let process pa pr getdir useast = pr (parse_file pa getdir useast);;

let gind =
  function
    (MLast.SgDir (loc, n, dp), _) :: _ -> Some (loc, n, dp)
  | _ -> None
;;

let gimd =
  function
    (MLast.StDir (loc, n, dp), _) :: _ -> Some (loc, n, dp)
  | _ -> None
;;

let usesig loc fname ast = MLast.SgUse (loc, fname, ast);;
let usestr loc fname ast = MLast.StUse (loc, fname, ast);;

let process_intf () =
  process !(Pcaml.parse_interf) !(Pcaml.print_interf) gind usesig
;;
let process_impl () =
  process !(Pcaml.parse_implem) !(Pcaml.print_implem) gimd usestr
;;

type file_kind =
    Intf
  | Impl
;;
let file_kind = ref Intf;;
let file_kind_of_name name =
  if Filename.check_suffix name ".mli" then Intf
  else if Filename.check_suffix name ".ml" then Impl
  else raise (Arg.Bad ("don't know what to do with " ^ name))
;;

let print_version () =
  eprintf "Camlp4s version %s\n" Pcaml.version; flush stderr; exit 0
;;

let align_doc key s =
  let s =
    let rec loop i =
      if i = String.length s then ""
      else if s.[i] = ' ' then loop (i + 1)
      else String.sub s i (String.length s - i)
    in
    loop 0
  in
  let (p, s) =
    if String.length s > 0 then
      if s.[0] = '<' then
        let rec loop i =
          if i = String.length s then "", s
          else if s.[i] <> '>' then loop (i + 1)
          else
            let p = String.sub s 0 (i + 1) in
            let rec loop i =
              if i >= String.length s then p, ""
              else if s.[i] = ' ' then loop (i + 1)
              else p, String.sub s i (String.length s - i)
            in
            loop (i + 1)
        in
        loop 0
      else "", s
    else "", ""
  in
  let tab =
    String.make (max 1 (13 - String.length key - String.length p)) ' '
  in
  p ^ tab ^ s
;;

let make_symlist l =
  match l with
    [] -> "<none>"
  | h :: t -> List.fold_left (fun x y -> x ^ "|" ^ y) ("{" ^ h) t ^ "}"
;;

let print_usage_list l =
  List.iter
    (fun (key, spec, doc) ->
       match spec with
         Arg.Symbol (symbs, _) ->
           let s = make_symlist symbs in
           let synt = key ^ " " ^ s in
           eprintf "  %s %s\n" synt (align_doc synt doc)
       | _ -> eprintf "  %s %s\n" key (align_doc key doc))
    l
;;

let usage ini_sl ext_sl =
  eprintf "\
Usage: camlp4 [load-options] [--] [other-options]
Load options:
  -I directory  Add directory in search patch for object files.
  -where        Print camlp4 library directory and exit.
  -nolib        No automatic search for object files in library directory.
  <object-file> Load this file in Camlp4 core.
Other options:
  <file>        Parse this file.\n";
  print_usage_list ini_sl;
  begin
    let rec loop =
      function
        (y, _, _) :: _ when y = "-help" -> ()
      | _ :: sl -> loop sl
      | [] -> eprintf "  -help         Display this list of options.\n"
    in
    loop (ini_sl @ ext_sl)
  end;
  if ext_sl <> [] then
    begin
      eprintf "Options added by loaded object files:\n";
      print_usage_list ext_sl
    end
;;

let initial_spec_list =
  ["-intf", Arg.String (fun x -> file_kind := Intf; Pcaml.input_file := x),
   "<file>  Parse <file> as an interface, whatever its extension.";
   "-impl", Arg.String (fun x -> file_kind := Impl; Pcaml.input_file := x),
   "<file>  Parse <file> as an implementation, whatever its extension.";
   "-unsafe", Arg.Set Ast2pt.fast,
   "Generate unsafe accesses to array and strings.";
   "-noassert", Arg.Set Pcaml.no_assert, "Don't compile assertion checks.";
   "-verbose", Arg.Set Grammar.error_verbose,
   "More verbose in parsing errors.";
   "-loc", Arg.String (fun x -> Stdpp.loc_name := x),
   "<name>   Name of the location variable (default: " ^ !(Stdpp.loc_name) ^
     ")";
   "-QD", Arg.String (fun x -> Pcaml.quotation_dump_file := Some x),
   "<file> Dump quotation expander result in case of syntax error.";
   "-o", Arg.String (fun x -> Pcaml.output_file := Some x),
   "<file> Output on <file> instead of standard output.";
   "-v", Arg.Unit print_version, "Print Camlp4s version and exit."]
;;

let anon_fun x = Pcaml.input_file := x; file_kind := file_kind_of_name x;;

let parse spec_list anon_fun remaining_args =
  let spec_list =
    Sort.list (fun (k1, _, _) (k2, _, _) -> k1 >= k2) spec_list
  in
  try parse_aux spec_list anon_fun remaining_args with
    Arg.Bad s ->
      eprintf "Error: %s\n" s;
      eprintf "Use option -help for usage\n";
      flush stderr;
      exit 2
;;

let remaining_args =
  let rec loop l i =
    if i == Array.length Sys.argv then l else loop (Sys.argv.(i) :: l) (i + 1)
  in
  List.rev (loop [] (!(Arg.current) + 1))
;;

let report_error =
  function
    Odyl_main.Error (fname, msg) ->
      Format.print_string "Error while loading \"";
      Format.print_string fname;
      Format.print_string "\": ";
      Format.print_string msg
  | exc -> Pcaml.report_error exc
;;

let go () =
  let ext_spec_list = Pcaml.arg_spec_list () in
  let arg_spec_list = initial_spec_list @ ext_spec_list in
  begin match parse arg_spec_list anon_fun remaining_args with
    [] -> ()
  | "-help" :: sl -> usage initial_spec_list ext_spec_list; exit 0
  | s :: sl ->
      eprintf "%s: unknown or misused option\n" s;
      eprintf "Use option -help for usage\n";
      exit 2
  end;
  try
    if !(Pcaml.input_file) <> "" then
      match !file_kind with
        Intf -> process_intf ()
      | Impl -> process_impl ()
  with
    exc ->
      Format.set_formatter_out_channel stderr;
      Format.open_vbox 0;
      let exc =
        match exc with
          Stdpp.Exc_located ((bp, ep), exc) -> print_location (bp, ep); exc
        | _ -> exc
      in
      report_error exc; Format.close_box (); Format.print_newline (); exit 2
;;

Odyl_main.name := "camlp4";;
Odyl_main.go := go;;
