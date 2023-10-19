# wq - Work Queue

Work Queue is my entry for the Anders October 2023 hackathon. 
wq is a command line tool for quickly saving and querying todo 
tasks in a postgres database. It ranks tasks dynamically based 
on priority, age and optional deadlines. 

## The ranking 
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

