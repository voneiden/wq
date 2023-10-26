module Span = Timedesc.Span
module Timestamp = Timedesc.Timestamp
open Util

let tz = Timedesc.Time_zone.make_exn "Europe/Helsinki"
(* TODO customizable *)

let is_digit (c : char) = c >= '0' && c <= '9'
let string_to_char_list s = s |> String.to_seq |> List.of_seq

let buffer_to_int (buffer : char list) =
  buffer |> List.to_seq |> String.of_seq |> int_of_string

let%test _ = buffer_to_int [ '1'; '0' ] = 10
let%test _ = buffer_to_int [ '0'; '1' ] = 1

let rec parse_duration' (buffer : char list) (input : char list) =
  match input with
  | [ 'd' ] -> Some (make_time_span (24 * buffer_to_int buffer) 0 0)
  | [ 'h' ] ->
      Some (make_time_span (buffer_to_int buffer) 0 0)
      (* Use regular ints with a last cast?*)
  | x :: xs when is_digit x -> parse_duration' (buffer @ [ x ]) xs
  | _ -> None

let parse_duration (input : string) =
  input |> String.to_seq |> List.of_seq |> parse_duration' []

let%test _ = parse_duration "1d" = Some (make_time_span 24 0 0)
let%test _ = parse_duration "12h" = Some (make_time_span 12 0 0)

let mmdd_to_date m1 m2 d1 d2 =
  let now = Timedesc.now ~tz_of_date_time:tz () in
  let now_year = Timedesc.year now
  and now_date = Timedesc.date now
  and month = buffer_to_int [ m1; m2 ]
  and day = buffer_to_int [ d1; d2 ] in
  let this_year_date = make_date now_year month day in
  if this_year_date <= now_date then this_year_date
  else make_date (now_year + 1) month day

let yymmdd_to_date y1 y2 m1 m2 d1 d2 =
  let year = 2000 + buffer_to_int [ y1; y2 ]
  and month = buffer_to_int [ m1; m2 ]
  and day = buffer_to_int [ d1; d2 ] in
  make_date year month day

let%test _ = yymmdd_to_date '2' '4' '1' '1' '0' '5' = make_date 2024 11 5

(* TODO*)
let parse_deadline (end_of_day : Time.t) deadline : Timestamp.t option =
  match deadline with
  | None -> None
  | Some deadline -> (
      let now = now_timestamp () in
      match (string_to_char_list deadline, parse_duration deadline) with
      | _, Some duration -> Some (Timestamp.add now duration)
      | [ m1; m2; d1; d2 ], _ ->
          Some
            (make_timestamp_of_date_and_time (mmdd_to_date m1 m2 d1 d2)
               end_of_day)
      | [ y1; y2; m1; m2; d1; d2 ], _ ->
          Some
            (make_timestamp_of_date_and_time
               (yymmdd_to_date y1 y2 m1 m2 d1 d2)
               end_of_day)
      | _ -> None)
