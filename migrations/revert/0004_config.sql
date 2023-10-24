-- Revert wq:0004_config from pg

BEGIN;

DROP INDEX one_row_only_uidx;
DROP TABLE config;

COMMIT;
