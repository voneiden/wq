-- Deploy wq:0002_estimate to pg

BEGIN;

-- create new field named estimate (time interval)
ALTER TABLE task
    ADD COLUMN estimate INTERVAL;

COMMIT;
