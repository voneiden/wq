open Cmdliner
module Task = Wq.Task

let connect () =
  Caqti_lwt.connect @@ Uri.of_string "postgresql://wq@localhost/wq"

let exec_query query =
  let ( let* ) = Lwt_result.bind in
  let* conn = connect () in
  query conn

let priority_flags_to_priority_int low high =
  match (low, high) with true, false -> 0 | false, true -> 2 | _ -> 1

(* TODO*)
let parse_deadline _ = None

(* TODO*)
let parse_estimate _ = None

let parse_pos (pos : string list) =
  match pos with
  | [] -> (None, None)
  | [ index ]
    when try
           ignore (int_of_string index);
           true
         with _ -> false ->
      (None, Some (int_of_string index))
  | _ -> (Some (String.concat " " pos), None)

let main (pos : string list) (low : bool) (high : bool)
    (deadline : string option) (estimate : float option) =
  match (parse_pos pos, low, high) with
  | _, true, true -> print_endline "Error: ambiguous priority"
  | (Some title, _), _, _ -> (
      match
        Lwt_main.run
        @@ exec_query
             (Task.insert ~title
                ~priority:(priority_flags_to_priority_int low high)
                ~deadline:(parse_deadline deadline)
                ~estimate:(parse_estimate estimate))
      with
      | Error err ->
          print_endline "Oops, we encountered an error!";
          print_endline (Caqti_error.show err)
      | Ok () -> print_endline "oke")
  | (_, Some _), _, _ -> print_endline "Not supported"
  | _ -> (
      match Lwt_main.run @@ exec_query (Task.list_with_score ()) with
      | Error err ->
          print_endline "Oops, we encountered an error!";
          print_endline (Caqti_error.show err)
      | Ok rows ->
          let tasks = Task.to_tasks rows in
          List.iter Task.print_task tasks;
          Task.print_most_important tasks)

let arg_pos =
  let doc =
    "Title of the task (string) to create or index of the task to read \
     (integer)"
  in
  Arg.(value & pos_all string [] & info [] ~doc)

(*
let arg_title =
  let doc = "Title of task." in
  Arg.(
    value & opt (some string) None & info [ "t"; "title" ] ~docv:"TITLE" ~doc)
*)
let arg_low_priority =
  let doc = "Low priority task" in
  Arg.(value & flag & info [ "l"; "low" ] ~docv:"LOW" ~doc)

let arg_high_priority =
  let doc = "High priority task" in
  Arg.(value & flag & info [ "h"; "high" ] ~docv:"HIGH" ~doc)

let arg_deadline =
  let doc = "Deadline" in
  Arg.(
    value
    & opt (some string) None
    & info [ "d"; "date" ] ~docv:"YYMMDD[THH[:MM[:SS]]]" ~doc)

let arg_estimate_hours =
  let doc = "Estimate (hours)" in
  Arg.(value & opt (some float) None & info [ "e"; "estimate" ] ~docv:"n" ~doc)

(* TODO deadline and estimate args *)
let main_t =
  Term.(
    const main $ arg_pos $ arg_low_priority $ arg_high_priority $ arg_deadline
    $ arg_estimate_hours)

let cmd = Cmd.v (Cmd.info "Work Queue") main_t
let () = exit (Cmd.eval cmd)
