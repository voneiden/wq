-- Verify wq:0001_initial on pg

begin;
-- verify that we have access to table task
select * from task limit 1;
rollback;
