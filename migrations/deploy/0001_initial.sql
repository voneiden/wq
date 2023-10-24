-- Deploy wq:0001_initial to pg

BEGIN;

CREATE TABLE task
(
    id         SERIAL PRIMARY KEY,
    title      VARCHAR(1000) NOT NULL,
    priority   INTEGER       NOT NULL,
    deadline   TIMESTAMPTZ,
    created_at TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMIT;
