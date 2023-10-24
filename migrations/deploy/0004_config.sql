-- Deploy wq:0004_config to pg

BEGIN;

-- Create table config
CREATE TABLE config
(
    id        SERIAL PRIMARY KEY,
    timezone  TEXT NOT NULL,
    day_start TIME NOT NULL,
    day_end   TIME NOT NULL
);

CREATE UNIQUE INDEX one_row_only_uidx ON config ((TRUE));

INSERT INTO config (timezone, day_start, day_end)
VALUES ('Europe/Helsinki', '09:00', '16:00');

COMMIT;
