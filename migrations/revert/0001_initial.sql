-- Revert wq:0001_initial from pg

BEGIN;

DROP TABLE task;

COMMIT;
