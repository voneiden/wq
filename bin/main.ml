module Task = Wq.Task

let connect () =
  Caqti_lwt.connect @@ Uri.of_string "postgresql://wq@localhost/wq"

let exec_query () =
  let ( let* ) = Lwt_result.bind in
  let* conn = connect () in
  Task.list_with_score () conn

let () =
  match Lwt_main.run @@ exec_query () with
  | Error err ->
      print_endline "Oops, we encountered an error!";
      print_endline (Caqti_error.show err)
  | Ok rows ->
      let tasks = Task.to_tasks rows
      in
      List.iter Task.print_task tasks;
      Task.print_most_important tasks
