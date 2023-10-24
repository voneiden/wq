let tz = Timedesc.Time_zone.make_exn "Europe/Helsinki"
(* TODO customizable *)

module Timestamp = Timedesc.Timestamp
module Span = Timedesc.Span
module Time = Timedesc.Time
module Date = Timedesc.Date

type db_task = {
  id : int;
  title : string;
  priority : int;
  deadline : Timestamp.t option;
  estimate : Span.t option;
  score : float;
  closed : bool;
}

let make_timestamp year month day hour minute second =
  Timedesc.to_timestamp_single
  @@ Timedesc.make_exn ~tz ~year ~month ~day ~hour ~minute ~second ()

let make_time hour minute second = Time.make_exn ~hour ~minute ~second ()

let make_time_span hour minute second =
  Time.to_span @@ make_time hour minute second

let to_db_task ~id ~title ~priority ~deadline ~estimate ~closed ~score =
  {
    id;
    title;
    priority;
    deadline = Option.map Timedesc.Utils.timestamp_of_ptime deadline;
    estimate = Option.map Timedesc.Utils.span_of_ptime_span estimate;
    score;
    closed;
  }

type task = { db_task : db_task; start_time : Timestamp.t option }

let timestamp_add_days days (timestamp : Timestamp.t) =
  let datetime = Timedesc.of_timestamp_exn ~tz_of_date_time:tz timestamp in
  Timedesc.of_date_and_time_exn
    (Date.add ~days (Timedesc.date datetime))
    (Timedesc.time datetime)
  |> Timedesc.to_timestamp_single

let set_timestamp_time (time : Time.t) (timestamp : Timestamp.t) =
  let datetime = Timedesc.of_timestamp_exn ~tz_of_date_time:tz timestamp in
  Timedesc.of_date_and_time_exn ~tz (Timedesc.date datetime) time
  |> Timedesc.to_timestamp_single

let%test _ =
  set_timestamp_time
    (Time.make_exn ~hour:16 ~minute:59 ~second:45 ())
    (Timedesc.make_exn ~tz ~year:2023 ~month:10 ~day:19 ~hour:8 ~minute:0
       ~second:0 ()
    |> Timedesc.to_timestamp_single)
  = (Timedesc.make_exn ~year:2023 ~month:10 ~day:19 ~hour:16 ~minute:59
       ~second:45 ()
    |> Timedesc.to_timestamp_single)

let rec subtract_work_time (day_start : Time.t) (day_end : Time.t)
    (time : Span.t) (timestamp : Timestamp.t) =
  let recurse = subtract_work_time day_start day_end in
  let dt = Timedesc.of_timestamp_exn ~tz_of_date_time:tz timestamp in
  match Timedesc.weekday dt with
  | `Sun ->
      timestamp_add_days (-2) timestamp
      |> set_timestamp_time day_end |> recurse time
  | `Sat ->
      timestamp_add_days (-1) timestamp
      |> set_timestamp_time day_end |> recurse time
  | _ ->
      let day_start_timestamp = set_timestamp_time day_start timestamp
      and day_end_timestamp = set_timestamp_time day_end timestamp in
      if timestamp > day_end_timestamp then
        set_timestamp_time day_end timestamp |> recurse time
      else if timestamp <= day_start_timestamp then
        timestamp_add_days (-1) timestamp
        |> set_timestamp_time day_end |> recurse time
      else
        let day_max_work_time =
          Span.sub day_end_timestamp day_start_timestamp
        in
        let actual_day_work_time = min day_max_work_time time in
        let remaining_time = Span.sub time actual_day_work_time
        and new_moment = Span.sub timestamp actual_day_work_time in
        if remaining_time = Span.zero then new_moment
        else recurse remaining_time new_moment

let%test _ =
  subtract_work_time (make_time 8 0 0) (make_time 16 0 0) (make_time_span 2 0 0)
    (make_timestamp 2023 10 15 23 0 0)
  = make_timestamp 2023 10 13 14 0 0

let%test _ =
  subtract_work_time (make_time 8 0 0) (make_time 16 0 0)
    (make_time_span 12 0 0)
    (make_timestamp 2023 10 15 23 0 0)
  = make_timestamp 2023 10 12 12 0 0

let deadline_or_override (deadline : Timestamp.t option)
    (override : Timestamp.t option) =
  match (deadline, override) with
  | Some deadline, Some override -> Some (min deadline override)
  | Some deadline, None -> Some deadline
  | _ -> None

let determine_start_time (end_time : Timestamp.t) : Timestamp.t =
  subtract_work_time (make_time 8 0 0)
    (make_time 16 0 0) (* TODO make configurable*)
    (make_time_span 1 0 0) (* TODO: make dynamic*)
    end_time

let sort_optional (getter : 'a -> 'b option) (compare : 'b -> 'b -> int)
    (o1 : 'a) (o2 : 'a) : int =
  match (getter o1, getter o2) with
  | Some d1, Some d2 -> compare d1 d2
  | Some _, None -> 1
  | None, Some _ -> -1
  | None, None -> 0

let select_earliest_start_time (tasks : task list) : task option =
  let start_tasks =
    tasks
    |> List.filter (fun task -> Option.is_some task.start_time)
    |> List.sort (sort_optional (fun task -> task.start_time) Timestamp.compare)
  in
  match start_tasks with hd :: _ -> Some hd | _ -> None

let task_factory (hour : int) =
  {
    start_time = Some (make_timestamp 2023 10 20 hour 0 0);
    db_task =
      {
        score = 0.0;
        deadline = None;
        closed = false;
        estimate = None;
        priority = 0;
        id = 1;
        title = "test";
      };
  }

let%test _ = select_earliest_start_time [] = None

let%test _ =
  select_earliest_start_time
    [ task_factory 12; task_factory 10; task_factory 14 ]
  = Some (task_factory 10)

let select_most_important (now : Timestamp.t) (tasks : task list) : task option
    =
  let earliest_start_time = select_earliest_start_time tasks in
  match earliest_start_time with
  | Some { start_time = Some start_time; _ } when start_time < now ->
      earliest_start_time
  | _ -> (
      match
        tasks
        |> List.sort (fun t1 t2 ->
               Float.compare t1.db_task.score t2.db_task.score)
        |> List.rev
      with
      | hd :: _ -> Some hd
      | _ -> None)

let to_tasks (db_tasks : db_task list) : task list =
  db_tasks
  |> List.sort
       (sort_optional (fun db_task -> db_task.deadline) Timestamp.compare)
  |> List.rev
  |> List.fold_left_map
       (fun previous_start db_task ->
         let start_time =
           Option.map determine_start_time
             (deadline_or_override db_task.deadline previous_start)
         in
         (start_time, { db_task; start_time }))
       None
  |> snd

let db_task_factory (hour : int) =
  {
    id = 1;
    deadline = Some (make_timestamp 2023 10 20 hour 0 0);
    closed = false;
    estimate = None;
    title = "";
    priority = 0;
    score = 0.0;
  }

let%test _ = to_tasks [] = []

let%test _ =
  to_tasks [ db_task_factory 10 ]
  = [
      {
        start_time = Some (make_timestamp 2023 10 20 9 0 0);
        db_task = db_task_factory 10;
      };
    ]

let print_most_important (tasks : task list) =
  match select_most_important (Timestamp.now ()) tasks with
  | Some { db_task = { id; title; _ }; _ } ->
      Printf.printf "The most important task (id=%i): %s" id title
  | None -> Printf.printf "Nothing to do!"

let print_task (row : task) =
  match row with
  | {
   db_task = { id; title; score; deadline = Some deadline; _ };
   start_time = Some start_time;
  } ->
      Printf.printf
        "Returned row id %i with title \"%s\" and score %f -- start at %s \
         (deadline at %s)\n"
        id title score
        (Timestamp.to_string start_time)
        (Timestamp.to_string deadline)
  | { db_task = { id; title; score; _ }; _ } ->
      Printf.printf "Returned row id %i with title \"%s\" and score %f\n" id
        title score

let insert =
  [%rapper
    execute
      {sql|
        INSERT INTO task(title, priority, deadline, estimate)
        VALUES (%string{title}, %int{priority}, %ptime?{deadline}, %ptime_span?{estimate})
      |sql}]

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
            estimate,
            created_at,
            closed,
            pow(pow(2, priority), 2) as p_factor,
            extract(epoch from (now() - created_at)) / 86400.0 as age,
            extract(epoch from (deadline - NOW())) / 86400.0 as ttl
          FROM task 
          WHERE closed = false
        )
        SELECT 
          @int{id}, 
          @string{title}, 
          @int{priority}, 
          @ptime?{deadline}, 
          @ptime_span?{estimate},
          @bool{closed},
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
      function_out]
    to_db_task
