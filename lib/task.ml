let tz = Timedesc.Time_zone.make_exn "Europe/Helsinki"
(* TODO customizable *)

module Timestamp = Timedesc.Timestamp
module Span = Timedesc.Span
module Time = Timedesc.Time
module Date = Timedesc.Date
open Util

type db_config = { timezone : string; day_start : Time.t; day_end : Time.t }

let to_db_config ~timezone ~day_start ~day_end =
  let day_start = day_start |> Timedesc.Utils.span_of_ptime_span |> Time.of_span
  and day_end = day_end |> Timedesc.Utils.span_of_ptime_span |> Time.of_span in
  match (day_start, day_end) with
  | Some day_start, Some day_end -> Ok { timezone; day_start; day_end }
  | _ -> Error "Error: Config has inconsistent day_start / day_end"

type db_task = {
  id : int;
  title : string;
  priority : int;
  deadline : Timestamp.t option;
  estimate : Span.t option;
  score : float;
  closed : bool;
}

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

let span_to_ptime span =
  span
  |> Span.add
       (Timedesc.to_timestamp_single (Timedesc.now ~tz_of_date_time:tz ()))
  |> Timedesc.Utils.ptime_of_timestamp

let timestamp_add_days days (timestamp : Timestamp.t) =
  let datetime = Timedesc.of_timestamp_exn ~tz_of_date_time:tz timestamp in
  Timedesc.of_date_and_time_exn
    (Date.add ~days (Timedesc.date datetime))
    (Timedesc.time datetime)
  |> Timedesc.to_timestamp_single

let%test _ =
  set_timestamp_time
    (Time.make_exn ~hour:16 ~minute:59 ~second:45 ())
    (Timedesc.make_exn ~tz ~year:2023 ~month:10 ~day:19 ~hour:8 ~minute:0
       ~second:0 ()
    |> Timedesc.to_timestamp_single)
  = (Timedesc.make_exn ~tz ~year:2023 ~month:10 ~day:19 ~hour:16 ~minute:59
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

let determine_start_time cfg (estimate : Span.t option) (end_time : Timestamp.t)
    : Timestamp.t =
  subtract_work_time cfg.day_start cfg.day_end
    (Option.value estimate ~default:(make_time_span 1 0 0))
    end_time

let sort (getter : 'a -> 'b) (compare : 'b -> 'b -> int) (o1 : 'a) (o2 : 'a) :
    int =
  compare (getter o1) (getter o2)

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

let should_order_by_start_time now (task : task) =
  match task.start_time with Some start_time -> start_time <= now | _ -> false

let to_tasks now cfg (db_tasks : db_task list) : task list =
  let order_by_start_time, order_by_score =
    db_tasks
    |> List.sort
         (sort_optional (fun db_task -> db_task.deadline) Timestamp.compare)
    |> List.rev
    |> List.fold_left_map
         (fun previous_start db_task ->
           let start_time =
             Option.map
               (determine_start_time cfg db_task.estimate)
               (deadline_or_override db_task.deadline previous_start)
           in
           (start_time, { db_task; start_time }))
         None
    |> snd
    |> List.partition (should_order_by_start_time now)
  in
  List.concat
    [
      order_by_start_time
      |> List.sort
           (sort_optional (fun task -> task.start_time) Timestamp.compare);
      order_by_score
      |> List.sort (sort (fun task -> task.db_task.score) Float.compare)
      |> List.rev;
    ]

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

let db_config_factory () =
  {
    timezone = "Europe/Helsinki";
    day_start = make_time 8 0 0;
    day_end = make_time 16 0 0;
  }

let%test _ =
  to_tasks (make_timestamp 2023 10 27 22 22 22) (db_config_factory ()) [] = []

let%test _ =
  to_tasks
    (make_timestamp 2023 10 27 22 22 22)
    (db_config_factory ())
    [ db_task_factory 10 ]
  = [
      {
        start_time = Some (make_timestamp 2023 10 20 9 0 0);
        db_task = db_task_factory 10;
      };
    ]

let print_most_important (tasks : task list) =
  match select_most_important (Timestamp.now ()) tasks with
  | Some { db_task = { id; title; _ }; _ } ->
      Printf.printf "The most important task (id=%i): %s\n" id title
  | None -> Printf.printf "Nothing to do!"

let print_index index = if index >= 0 then Printf.sprintf "%i" index else ""

(* TODO test ANSI colors like \027[31m *)
let print_priority_symbol priority =
  match priority with 2 -> "⇑" | 0 -> "⇣" | _ -> ""

let deadline_symbol deadline = match deadline with None -> "" | Some _ -> "⏱"

let print_padding tl priority deadline =
  let priority = if priority == 2 || priority == 0 then 1 else 0
  and deadline = if Option.is_some deadline then 1 else 0 in
  String.make (5 - (String.length tl + priority + deadline)) ' '

let print_prefix index priority deadline =
  let index = print_index index
  and string_priority = print_priority_symbol priority
  and string_deadline = deadline_symbol deadline in

  match (index, String.concat "" [ string_priority; string_deadline ]) with
  | "", "" -> ""
  | "", tl -> Printf.sprintf "[%s%s]" (print_padding "" priority deadline) tl
  | hd, "" -> Printf.sprintf "[%s%s]" hd (print_padding hd priority deadline)
  | hd, tl ->
      Printf.sprintf "[%s%s%s]" hd (print_padding hd priority deadline) tl

let print_task (index : int) (row : task) =
  match row with
  | { db_task = { title; priority; deadline; _ }; _ } ->
      Printf.printf "%s %s\n" (print_prefix index priority deadline) title

let insert =
  [%rapper
    execute
      {sql|
        INSERT INTO task(title, priority, deadline, estimate)
        VALUES (%string{title}, %int{priority}, %ptime?{deadline}, %ptime_span?{estimate})
      |sql}]

let toggle_closed =
  [%rapper
    execute
      {sql|
        UPDATE task
        SET closed = NOT closed
        WHERE id = %int{id}
      |sql}]

let toggle_locked =
  [%rapper
    execute
      {sql|
        UPDATE task
        SET locked = NOT locked
        WHERE id = %int{id}
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

let get_config =
  [%rapper
    get_one
      {sql|
        SELECT 
          @string{timezone}, 
          @ptime_span{day_start}, 
          @ptime_span{day_end}
        FROM config
        LIMIT 1
        |sql}
      function_out]
    to_db_config
