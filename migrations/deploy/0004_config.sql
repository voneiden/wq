-- Deploy wq:0004_config to pg

BEGIN;

-- Create table config
CREATE TABLE config
(
    id        serial PRIMARY KEY,
    timezone  text NOT NULL,
    day_start time NOT NULL,
    day_end   time NOT NULL
);

CREATE UNIQUE INDEX one_row_only_uidx ON config ((true));

INSERT INTO config (timezone, day_start, day_end)
VALUES ('Europe/Helsinki', '09:00', '16:00');

COMMIT;
