type model = {
  id : int;
  title : string;
  priority : int;
  deadline : Ptime.t option;
  score : float;
}


let collect_and_sort_deadlines(tasks : model list) =
  tasks
  |> List.filter_map (fun task -> 
    match task.deadline with 
      | Some deadline -> Some (task.id, deadline)
      | _ -> None
      )  
  |> List.sort (fun t1 t2 ->
      match (t1, t2) with 
      | ((_, d1), (_, d2)) -> Ptime.compare d1 d2 
  )
  |> List.rev
  |> List.iter (fun (id, deadline) -> Printf.printf "Hello %i @ %s\n" id (Ptime.to_rfc3339 deadline))
  
let sorted_by_deadline(tasks : model list) =
  tasks
  |> List.filter (fun task -> task.deadline <> None)  
  |> List.sort (fun t1 t2 -> 
      match (t1.deadline, t2.deadline) with 
      | (Some d1, Some d2) -> Ptime.compare d1 d2
      | (_, _) -> 0
    )
  

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
          @ptime?{deadline}, 
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
