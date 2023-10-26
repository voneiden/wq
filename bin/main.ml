open Cmdliner
module Task = Wq.Task
module Time = Timedesc.Span
module Span = Timedesc.Span
module Parse = Wq.Parse

let connect () =
  Caqti_lwt.connect @@ Uri.of_string "postgresql://wq@localhost/wq"

let exec_query query =
  let ( let* ) = Lwt_result.bind in
  let* conn = connect () in
  query conn

let priority_flags_to_priority_int low high =
  match (low, high) with true, false -> 0 | false, true -> 2 | _ -> 1

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

let list_tasks cfg =
  match Lwt_main.run @@ exec_query (Task.list_with_score ()) with
  | Error err ->
      print_endline "Oops, we encountered an error!";
      print_endline (Caqti_error.show err)
  | Ok rows ->
      let tasks = Task.to_tasks cfg rows in
      List.iter Task.print_task tasks;
      Task.print_most_important tasks

let insert_task (cfg : Task.db_config) title low high deadline estimate =
  match
    Lwt_main.run
    @@ exec_query
         (Task.insert ~title
            ~priority:(priority_flags_to_priority_int low high)
            ~deadline:
              (Option.bind
                 (Parse.parse_deadline cfg.day_end deadline)
                 Timedesc.Utils.ptime_of_timestamp)
            ~estimate:
              (Option.bind
                 (Option.bind estimate Parse.parse_duration)
                 Timedesc.Utils.ptime_span_of_span))
  with
  | Error err ->
      print_endline "Oops, we encountered an error!";
      print_endline (Caqti_error.show err)
  | Ok () -> print_endline "oke"

let get_config () =
  match Lwt_main.run @@ exec_query (Task.get_config ()) with
  | Error err ->
      print_endline "Failed to get config";
      print_endline (Caqti_error.show err);
      None
  | Ok cfg -> cfg

let main (pos : string list) (low : bool) (high : bool)
    (deadline : string option) (estimate : string option) =
  let cfg = get_config () in
  match (cfg, parse_pos pos, low, high) with
  | None, _, _, _ -> print_endline "Error: could not get config"
  | _, _, true, true -> print_endline "Error: ambiguous priority"
  | Some cfg, (Some title, _), _, _ ->
      insert_task cfg title low high deadline estimate
  | _, (_, Some _), _, _ -> print_endline "Not supported"
  | Some cfg, _, _, _ -> list_tasks cfg

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
    & info [ "d"; "deadline" ] ~docv:"[YY]MMDD or n[h|d]" ~doc)

let arg_estimate_hours =
  let doc = "Estimate" in
  Arg.(
    value
    & opt (some string) None
    & info [ "e"; "estimate" ] ~docv:"n[h|d]" ~doc)

(* TODO deadline and estimate args *)
let main_t =
  Term.(
    const main $ arg_pos $ arg_low_priority $ arg_high_priority $ arg_deadline
    $ arg_estimate_hours)

let cmd = Cmd.v (Cmd.info "Work Queue") main_t
let () = exit (Cmd.eval cmd)
