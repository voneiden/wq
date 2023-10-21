-- Revert wq:0002_estimate from pg

BEGIN;

-- Remove field estimate from table task
ALTER TABLE task DROP COLUMN estimate;

COMMIT;
