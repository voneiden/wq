-- Deploy wq:0003_task_closed to pg

BEGIN;

alter table task add column closed boolean default false not null;

COMMIT;
