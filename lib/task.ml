module Calendar = CalendarLib.Calendar
module Period = CalendarLib.Period

type model = {
  id : int;
  title : string;
  priority : int;
  deadline : Calendar.t option;
  score : float;
}

let determine_start_times (tasks : (int * Calendar.t) list) =
  match tasks with
  | [] -> []
  | hd :: _ -> (
      match hd with
      | _, first_deadline -> (
          let results =
            List.fold_left_map
              (fun last_end (id, deadline) ->
                let new_end = min last_end deadline in
                let start = Calendar.rem new_end (Calendar.Period.hour 1) in
                (start, (id, start, deadline)))
              first_deadline tasks
          in
          match results with _, foo -> foo))

let collect_and_sort_deadlines (tasks : model list) =
  tasks
  |> List.filter_map (fun task ->
         match task.deadline with
         | Some deadline -> Some (task.id, deadline)
         | _ -> None)
  |> List.sort (fun t1 t2 ->
         match (t1, t2) with (_, d1), (_, d2) -> Calendar.compare d1 d2)
  |> List.rev |> determine_start_times
  |> List.iter (fun (id, start, deadline) ->
         Printf.printf "Hello X %i @ %s --> %s\n" id
           (CalendarLib.Printer.Calendar.to_string start)
           (CalendarLib.Printer.Calendar.to_string deadline))

(* Printf.printf "Hello %i @ %s\n" id (Ptime.to_rfc3339 deadline)) *)

let print_task (row : model) =
  match row with
  | { id; title; score; _ } ->
      Printf.printf "Returned row id %i with title \"%s\" and score %f\n" id
        title score

let list_with_score =
  [%rapper
    get_many
      {sql|
        WITH cte AS (
          SELECT 
            id, 
            title, 
            priority, 
            deadline, 
            created_at,
            pow(pow(2, priority), 2) as p_factor,
            extract(epoch from (now() - created_at)) / 86400.0 as age,
            extract(epoch from (deadline - NOW())) / 86400.0 as ttl
          FROM task 
        )
        SELECT 
          @int{id}, 
          @string{title}, 
          @int{priority}, 
          @ctime?{deadline}, 
          p_factor * age +
            CASE
              WHEN ttl IS NOT NULL THEN 
                p_factor / (0.01 * exp(ttl))
              ELSE 0
            END 
            AS @float{score}
        FROM cte
        ORDER BY score DESC
        |sql}
      record_out]
