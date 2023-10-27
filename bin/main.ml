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

let priority_flags_to_priority low high =
  match (low, high) with
  | true, false -> Ok 0
  | false, true -> Ok 2
  | false, false -> Ok 1
  | true, true -> Error "Error: ambiguous priority"

type pos = Index of int | Title of string

let parse_pos (pos : string list) =
  match pos with
  | [] -> None
  | [ index ]
    when try
           ignore (int_of_string index);
           true
         with _ -> false ->
      Some (Index (int_of_string index))
  | _ -> Some (Title (String.concat " " pos))

let list_tasks_err now cfg =
  match Lwt_main.run @@ exec_query (Task.list_with_score ()) with
  | Error err ->
      Error
        (String.concat "\n"
           [ "Error: Listing tasks failed"; Caqti_error.show err ])
  | Ok rows -> Ok (Task.to_tasks now cfg rows)

let insert_task (cfg : Task.db_config) title low high deadline estimate =
  match priority_flags_to_priority low high with
  | Error msg -> Error msg
  | Ok priority -> (
      match
        Lwt_main.run
        @@ exec_query
             (Task.insert ~title ~priority
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
          Error
            (String.concat "\n"
               [ "Error: Inserting task failed"; Caqti_error.show err ])
      | Ok () -> Ok ())

let get_config () =
  match Lwt_main.run @@ exec_query (Task.get_config ()) with
  | Error err ->
      Error
        (String.concat "\n" [ "Failed to get config"; Caqti_error.show err ])
  | Ok cfg_result -> cfg_result

let lock_task id =
  match id with
  | None -> Error "Error: No task to lock"
  | Some id -> (
      match Lwt_main.run @@ exec_query (Task.toggle_locked ~id) with
      | Error err ->
          Error
            (String.concat "\n"
               [ "Failed to lock/unlock task"; Caqti_error.show err ])
      | Ok () -> Ok ())

let close_task id =
  match id with
  | None -> Error "Error: No task to close"
  | Some id -> (
      match Lwt_main.run @@ exec_query (Task.toggle_closed ~id) with
      | Error err ->
          Error
            (String.concat "\n"
               [ "Failed to close/open task"; Caqti_error.show err ])
      | Ok () -> Ok ())

let get_errors actions =
  List.filter_map
    (fun action -> match action with Some (Error msg) -> Some msg | _ -> None)
    actions

let print_errors actions =
  match get_errors actions with
  | [] -> ()
  | msgs -> List.iter print_endline msgs

let do_actions_for_task id close lock =
  [
    (if lock then Some (lock_task (Some id)) else None);
    (if close then Some (close_task (Some id)) else None);
  ]

let main (pos : string list) (low : bool) (high : bool)
    (deadline : string option) (estimate : string option) (close : bool)
    (lock : bool) =
  let now = Wq.Util.now_timestamp () in
  match get_config () with
  | Error msg -> print_endline msg
  | Ok cfg -> (
      (* First determine the tasks that we need to do *)
      match list_tasks_err now cfg with
      | Error msg -> print_endline msg
      | Ok tasks -> (
          match parse_pos pos with
          | None -> (
              match tasks with
              | [] -> print_endline "No tasks. How about make some first?"
              | most_important_task :: _ ->
                  print_errors
                    (do_actions_for_task most_important_task.db_task.id close
                       lock);
                  List.iteri Task.print_task tasks)
          | Some (Index index) -> (
              match List.nth_opt tasks index with
              | None -> print_endline "Error: Invalid index"
              | Some task ->
                  print_errors (do_actions_for_task task.db_task.id close lock);
                  Task.print_task (-1) task)
          | Some (Title title) ->
              let actions =
                List.concat
                  [
                    [ Some (insert_task cfg title low high deadline estimate) ];
                  ]
              in
              print_errors actions))
(*
  let cfg = get_config () in
  match (cfg, parse_pos pos, low, high, close, lock) with
  | Error msg, _, _, _, _, _ -> print_endline msg
  | _, _, true, true, _, _ -> print_endline "Error: ambiguous priority"
  | Ok cfg, (Some title, _), _, _, _, _ ->
      insert_task cfg title low high deadline estimate
  | _, (_, Some _), _, _, _, _ -> print_endline "Not supported"
  | Ok cfg, _, _, _, _, _ -> list_tasks cfg
  *)

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

let arg_close =
  let doc = "Close active task" in
  Arg.(value & flag & info [ "c"; "close" ] ~docv:"CLOSE" ~doc)

let arg_lock =
  let doc = "Lock/unlock active task" in
  Arg.(value & flag & info [ "x"; "lock" ] ~docv:"LOCK" ~doc)

(* TODO deadline and estimate args *)
let main_t =
  Term.(
    const main $ arg_pos $ arg_low_priority $ arg_high_priority $ arg_deadline
    $ arg_estimate_hours $ arg_close $ arg_lock)

let cmd = Cmd.v (Cmd.info "Work Queue") main_t
let () = exit (Cmd.eval cmd)
