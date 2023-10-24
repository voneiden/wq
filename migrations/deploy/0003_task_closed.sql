-- Deploy wq:0003_task_closed to pg

BEGIN;

ALTER TABLE task
    ADD COLUMN closed BOOLEAN DEFAULT FALSE NOT NULL;

COMMIT;
