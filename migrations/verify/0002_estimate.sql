-- Verify wq:0002_estimate on pg

DO $$
BEGIN
ASSERT (SELECT EXISTS (SELECT 1
               FROM information_schema.columns
               WHERE table_schema = 'public'
                 AND table_name = 'task'
                 AND column_name = 'estimate'));
END $$;
