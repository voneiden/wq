

let my_query =
  [%rapper
    get_opt
      {sql|
      WITH cte AS (
        SELECT 
          id, 
          title, 
          priority, 
          deadline, 
          created_at,
          pow(pow(2, priority), 2) as p_factor
        FROM task 
      )
      SELECT 
        @int{id}, 
        @string{title}, 
        @int{priority}, 
        @string?{deadline}, 
        p_factor * EXTRACT(EPOCH FROM (NOW() - created_at)) / 86400.0 +
          CASE
            WHEN deadline IS NOT NULL THEN 
              p_factor / (0.01 * exp(
                EXTRACT(EPOCH FROM (deadline - NOW())) / 86400.0)
              )
            ELSE 0
          END 
          AS @float{score}
      FROM cte
      ORDER BY score ASC
      LIMIT 1
      |sql}]


let connect () = 
  Caqti_lwt.connect @@ (Uri.of_string "postgresql://wq@localhost/wq")


let exec_query () = 
  let ( let* ) = Lwt_result.bind in
  let* conn = connect () in
  my_query () conn

let () =
  match Lwt_main.run @@ exec_query () with
  | Error err ->
      print_endline "Oops, we encountered an error!";
      print_endline (Caqti_error.show err)
  | Ok (Some (id, title, _, _, score)) -> Printf.printf "Returned row id %i with title \"%s\" and score %f\n" id title score
  | Ok None -> Printf.printf "Hello world\n" 
  

