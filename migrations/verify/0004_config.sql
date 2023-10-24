-- Verify wq:0004_config on pg
DO
$$
    DECLARE
        tz varchar;

    BEGIN

        tz := (SELECT timezone FROM config);
        ASSERT tz = 'Europe/Helsinki';


    END
$$;
