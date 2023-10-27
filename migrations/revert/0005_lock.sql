-- Revert wq:0005_lock from pg

BEGIN;

ALTER TABLE task
    DROP COLUMN locked;

COMMIT;
