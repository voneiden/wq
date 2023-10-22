open Cmdliner
module Task = Wq.Task

let connect () =
  Caqti_lwt.connect @@ Uri.of_string "postgresql://wq@localhost/wq"

let exec_query () =
  let ( let* ) = Lwt_result.bind in
  let* conn = connect () in
  Task.list_with_score () conn

let main (title : string option) (low : bool) (high : bool) =
  match (title, low, high) with
  | _, true, true -> print_endline "Can not set low and high priority"
  (* TODO create a new task*)
  | _ -> (
      match Lwt_main.run @@ exec_query () with
      | Error err ->
          print_endline "Oops, we encountered an error!";
          print_endline (Caqti_error.show err)
      | Ok rows ->
          let tasks = Task.to_tasks rows in
          List.iter Task.print_task tasks;
          Task.print_most_important tasks)

let arg_title =
  let doc = "Title of task." in
  Arg.(
    value & opt (some string) None & info [ "t"; "title" ] ~docv:"TITLE" ~doc)

let arg_low_priority =
  let doc = "Low priority task" in
  Arg.(value & flag & info [ "l"; "low" ] ~docv:"LOW" ~doc)

let arg_high_priority =
  let doc = "High priority task" in
  Arg.(value & flag & info [ "h"; "high" ] ~docv:"HIGH" ~doc)

(* TODO deadline and estimate args *)
let main_t =
  Term.(const main $ arg_title $ arg_low_priority $ arg_high_priority)

let cmd = Cmd.v (Cmd.info "Work Queue") main_t
let () = exit (Cmd.eval cmd)
