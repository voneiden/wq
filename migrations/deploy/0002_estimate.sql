-- Deploy wq:0002_estimate to pg

BEGIN;

-- create new field named estimate (time interval)
alter table task add column estimate interval;

COMMIT;
