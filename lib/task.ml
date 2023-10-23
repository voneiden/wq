module Calendar = CalendarLib.Calendar
module Date = CalendarLib.Date
module Period = CalendarLib.Period
module Time = CalendarLib.Time
module Printer = CalendarLib.Printer

type db_task = {
  id : int;
  title : string;
  priority : int;
  deadline : Calendar.t option;
  estimate : Ptime.span option;
  score : float;
  closed : bool;
}

type task = { db_task : db_task; start_time : Calendar.t option }

let ptime_span_to_calendar_period (span : Ptime.span option) =
  Option.bind span (fun span -> Ptime.Span.to_int_s span)
  |> Option.map (fun seconds -> Calendar.Period.make 0 0 0 0 0 seconds)

let%test _ =
  ptime_span_to_calendar_period (Some (Ptime.Span.of_int_s 100))
  = Some (Calendar.Period.make 0 0 0 0 1 40)

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

let deadline_or_override (deadline : Calendar.t option)
    (override : Calendar.t option) =
  match (deadline, override) with
  | Some deadline, Some override -> Some (min deadline override)
  | Some deadline, None -> Some deadline
  | _ -> None

let determine_start_time (end_time : Calendar.t) : Calendar.t =
  subtract_work_time (Time.make 8 0 0)
    (Time.make 16 0 0) (* TODO make configurable*)
    (Calendar.Period.make 0 0 0 1 0 0) (* TODO: make dynamic*)
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
    |> List.sort (sort_optional (fun task -> task.start_time) Calendar.compare)
  in
  match start_tasks with hd :: _ -> Some hd | _ -> None

let task_factory (hour : int) =
  {
    start_time = Some (Calendar.make 2023 10 20 hour 0 0);
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

let select_most_important (now : Calendar.t) (tasks : task list) : task option =
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
       (sort_optional (fun db_task -> db_task.deadline) Calendar.compare)
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
    deadline = Some (Calendar.make 2023 10 20 hour 0 0);
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
        start_time = Some (Calendar.make 2023 10 20 9 0 0);
        db_task = db_task_factory 10;
      };
    ]

let print_most_important (tasks : task list) =
  match select_most_important (Calendar.now ()) tasks with
  | Some { db_task = { id; title; _ }; _ } ->
      Printf.printf "The most important task (id=%i): %s" id title
  | None -> Printf.printf "Nothing to do!"

let print_task (row : task) =
  match row with
  | { db_task = { id; title; score; _ }; start_time = Some start_time } ->
      Printf.printf
        "Returned row id %i with title \"%s\" and score %f -- start at %s\n" id
        title score
        (Printer.CalendarPrinter.to_string start_time)
  | { db_task = { id; title; score; _ }; _ } ->
      Printf.printf "Returned row id %i with title \"%s\" and score %f\n" id
        title score

let insert =
  [%rapper
    execute
      {sql|
        INSERT INTO task(title, priority, deadline, estimate)
        VALUES (%string{title}, %int{priority}, %ctime?{deadline}, %ptime_span?{estimate})
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
          @ctime?{deadline}, 
          @bool{closed},
          @ptime_span?{estimate},
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
