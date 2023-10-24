-- Verify wq:0002_estimate on pg

BEGIN;

-- verify that table task has a field estimate
SELECT EXISTS (SELECT 1
               FROM information_schema.columns
               WHERE table_schema = 'wq'
                 AND table_name = 'task'
                 AND column_name = 'estimate');

ROLLBACK;
