-- Revert wq:0003_task_closed from pg

BEGIN;

ALTER TABLE task
    DROP COLUMN closed;

COMMIT;
