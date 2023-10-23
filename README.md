# wq - Work Queue

Work Queue is my entry for the Anders October 2023 hackathon. 
wq is a command line tool for quickly saving and querying todo 
tasks in a postgres database. It ranks tasks dynamically based 
on priority, age and optional deadlines. 


## Creating a task

`wq "Hello World"`

will create task an open task with medium priority and without deadlines, titled "Hello world".

### Adjusting priority

Priority can be adjusted with `-l` (`--low`) and `-h` (`--high`), eg

`wq -h "Hello World"`

will create a high priority task. 

### Setting a deadline

* `-d n` (`--date n`) - set deadline to n, where n can be a number of relative days or YYMMDD
* `-t hh:mm` (`--time hh:mmm`) - set deadline to specific time

If time is omitted, the default behaviour is to set the time to EOWD (end of work day). To set the time to end of day (23:59:59), use `-e` (`--end`)

### Setting an estimate

* `-e n[dh]` (`--estimate n[dh]`) - set estimate in days or hours (float). Days equal to work days. 

If estimate is omitted, it defaults to 1 hour

### Mark active task as done

`-d` (`--done`)


## Viewing tasks

`wq` with no arguments will return the task that is deemed as the most important

### View by index

`wq n` - where n is an integer >0 will view tasks based on score

### Listing tasks

`-a` (`--all`) will list all tasks sorted by score

## About ranking 
Task ranking is based on a score. The base score is formed by priority
and age of the task. The score can be further increased by an impending 
deadline. Additionally tasks with deadlines will override ranking
if it is necessary to do so to ensure the task is completed within the deadline.

### Priority
Each task has a priority (low [0], default [1], high [2]) which is converted 
into a priority factor `pow(pow(2, priority), 2)` yielding the following factors:

| Priority  | Priority factor |
| --------- | --------------- |
| Low       | 1               |
| Normal    | 4               |
| High      | 16              |


### Age and base score

Base score is calculated by multiplying the age of the task (in days) with the priority factor.

| Age (days) | Priority | Score |
| ---------- | -------- | ----- |
| 0          | Low      | 0     |
| 0          | Normal   | 0     |
| 0          | High     | 0     |
| 1          | Low      | 1     |
| 1          | Normal   | 4     |
| 1          | High     | 16    |
| 2          | Low      | 2     |
| 2          | Normal   | 8     |
| 2          | High     | 32    |


### Deadline and TTL

If a task has a deadline set, the score is increased by time left to deadline (ttl, days) using 

 `p_factor / (0.01 * exp(ttl))`

| TTL (days) | Priority | Score    |
| ---------- | -------- | -------- |
| 10         | Low      | ~0       |
| 10         | Normal   | ~0       |
| 10         | High     | ~0       |
| 1          | Low      | 36       |
| 1          | Normal   | 147      |
| 1          | High     | 588      |
| 0          | Low      | 100      |
| 0          | Normal   | 400      |
| 0          | High     | 1600     |
| -10        | Low      | 2202646  |
| -10        | Normal   | 8810586  |
| -10        | High     | 35242345 |


### Deadline will override score

wq also attempts to take into account work time required to complete a task by a deadline. It is possible
to give a time estimate (default 1 hour). If the start time of a task with the earliest deadline is reached, 
Wq will force the task on top of the priority list. Wq will also schedule work without overlapping work time. 
Default work time is 8-16 Mon-Fri. 

Example:
* Task 1 has deadline on Monday 09:00 and an estimate of 3 hours
* Task 2 has a deadline on Friday 16:00 and an estimate of 2 hours

--> Task 1 needs to be worked on latest Friday 14:00 - 16:00 and Monday 08:00 - 09:00
--> Task 2 needs to be worked before Task 1, so it is schedule to Friday 12:00 - 14:00

Therefore on Friday at 12:00, wq will prioritize Task 2 over everything else.

