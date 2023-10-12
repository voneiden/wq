-- Revert wq:0001_initial from pg

BEGIN;

drop table task;

COMMIT;
