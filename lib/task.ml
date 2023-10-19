module Calendar = CalendarLib.Calendar
module Date = CalendarLib.Date
module Period = CalendarLib.Period
module Time = CalendarLib.Time

type model = {
  id : int;
  title : string;
  priority : int;
  deadline : Calendar.t option;
  score : float;
}

let set_calendar_time (time : Calendar.Time.t) (calendar : Calendar.t) =
  Calendar.make (Calendar.year calendar)
    (Date.int_of_month @@ Calendar.month calendar)
    (Calendar.day_of_month calendar)
    (Time.hour time) (Time.minute time) (Time.second time)

let%test _ =
  set_calendar_time (Time.make 16 59 45) (Calendar.make 2023 10 19 8 0 0)
  = Calendar.make 2023 10 19 16 59 45

(* Given a day start and end times (eg. 8-16), subtract work time from a calendar *)
let rec subtract_work_time (day_start : Time.t) (day_end : Time.t)
    (time : Calendar.Period.t) (moment : Calendar.t) =
  let recurse = subtract_work_time day_start day_end in
  match Calendar.day_of_week moment with
  | Calendar.Sun ->
      Calendar.rem moment (Calendar.Period.day 2)
      |> set_calendar_time day_end |> recurse time
  | Calendar.Sat ->
      Calendar.rem moment (Calendar.Period.day 1)
      |> set_calendar_time day_end |> recurse time
  | _ ->
      let calendar_day_start = set_calendar_time day_start moment
      and calendar_day_end = set_calendar_time day_end moment in
      if moment > calendar_day_end then
        set_calendar_time day_end moment |> recurse time
      else if moment <= calendar_day_start then
        Calendar.rem moment (Calendar.Period.day 1)
        |> set_calendar_time day_end |> recurse time
      else
        let day_max_work_time =
          Calendar.sub calendar_day_end calendar_day_start
        in
        let actual_day_work_time = min day_max_work_time time in
        let remaining_time = Calendar.Period.sub time actual_day_work_time
        and new_moment = Calendar.rem moment actual_day_work_time in
        if remaining_time = Calendar.Period.empty then new_moment
        else recurse remaining_time new_moment

let%test _ =
  subtract_work_time (Time.make 8 0 0) (Time.make 16 0 0)
    (Calendar.Period.make 0 0 0 2 0 0)
    (Calendar.make 2023 10 15 23 0 0)
  = Calendar.make 2023 10 13 14 0 0

let%test _ =
  subtract_work_time (Time.make 8 0 0) (Time.make 16 0 0)
    (Calendar.Period.make 0 0 0 12 0 0)
    (Calendar.make 2023 10 15 23 0 0)
  = Calendar.make 2023 10 12 12 0 0

(*
let determine_start_times (tasks : (int * Calendar.t) list) =
  match tasks with
  | [] -> []
  | hd :: _ -> (
      match hd with
      | _, first_deadline -> (
          let results =
            List.fold_left_map
              (fun external_deadline (id, deadline) ->
                let active_deadline = min external_deadline deadline in
                let start =
                  Calendar.rem active_deadline (Calendar.Period.hour 1)
                in
                (start, (id, start, deadline)))
              first_deadline tasks
          in
          match results with _, foo -> foo))
*)

let collect_and_sort_deadlines (tasks : model list) =
  tasks
  |> List.filter_map (fun task ->
         match task.deadline with
         | Some deadline -> Some (task.id, deadline)
         | _ -> None)
  |> List.sort (fun t1 t2 ->
         match (t1, t2) with (_, d1), (_, d2) -> Calendar.compare d1 d2)
  |> List.rev

(* Given a list of (id, deadline) descending deadline pairs,
   return a list of (id, start_time) ascending start_time pairs *)
let determine_start_times (deadlines : (int * Calendar.t) list) :
    (int * Calendar.t) list =
  match deadlines with
  | [] -> []
  | hd :: _ -> (
      match hd with
      | _, first_deadline ->
          List.fold_left_map
            (fun max_deadline (id, deadline) ->
              let start_time =
                subtract_work_time (Time.make 8 0 0)
                  (Time.make 16 0 0) (* TODO make configurable*)
                  (Calendar.Period.make 0 0 0 1 0 0) (* TODO: make dynamic*)
                  (min max_deadline deadline)
              in
              (start_time, (id, start_time)))
            first_deadline deadlines
          |> snd |> List.rev)
(*
let deadline_priority_override (tasks : model list) : int option =
  match collect_and_sort_deadlines tasks with
  | [] -> None 
  | hd :: tl ->
    List.fold_left (fun acc (id ,deadline) -> acc) hd tl 
*)

let select_most_important (now : Calendar.t) (tasks : model list) : model option
    =
  let deadlines = collect_and_sort_deadlines tasks in
  let start_times = determine_start_times deadlines in
  match start_times with
  | (id, start_time) :: _ when start_time <= now ->
      List.find_opt (fun task -> task.id = id) tasks
  | _ -> ( match tasks with [] -> None | tl :: _ -> Some tl)

let print_most_important (tasks : model list) =
  match select_most_important (Calendar.now ()) tasks with
  | Some { id; title; _ } ->
      Printf.printf "The most important task (id=%i): %s" id title
  | None -> Printf.printf "Nothing to do!"

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
