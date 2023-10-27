module Date = Timedesc.Date
module Span = Timedesc.Span
module Time = Timedesc.Time
module Timestamp = Timedesc.Timestamp

let tz = Timedesc.Time_zone.make_exn "Europe/Helsinki"
(* TODO customizable *)

let make_timestamp year month day hour minute second =
  Timedesc.to_timestamp_single
  @@ Timedesc.make_exn ~tz ~year ~month ~day ~hour ~minute ~second ()

let make_time hour minute second = Time.make_exn ~hour ~minute ~second ()

let make_time_span hour minute second =
  (* Time.to_span @@ make_time hour minute second *)
  Span.make ~s:(Int64.of_int (second + (minute * 60) + (hour * 3600))) ()

let make_date year month day = Date.Ymd.make_exn ~year ~month ~day
let now () = Timedesc.now ~tz_of_date_time:tz ()
let now_timestamp () = Timedesc.to_timestamp_single @@ now ()

let set_timestamp_time (time : Time.t) (timestamp : Timestamp.t) =
  let datetime = Timedesc.of_timestamp_exn ~tz_of_date_time:tz timestamp in
  Timedesc.of_date_and_time_exn ~tz (Timedesc.date datetime) time
  |> Timedesc.to_timestamp_single

let make_timestamp_of_date_and_time date time =
  Timedesc.of_date_and_time_exn ~tz date time |> Timedesc.to_timestamp_single
