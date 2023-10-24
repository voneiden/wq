-- Verify wq:0001_initial on pg

begin;
-- verify that we have access to table task
SELECT * FROM task LIMIT 1;
rollback;
