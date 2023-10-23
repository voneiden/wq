-- Verify wq:0003_task_closed on pg

BEGIN;

SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'wq'
      AND table_name = 'task'
      AND column_name = 'closed'
);

ROLLBACK;
