-- Verify wq:0005_lock on pg

DO $$
BEGIN
ASSERT (SELECT EXISTS (SELECT 1
               FROM information_schema.columns
               WHERE table_schema = 'public'
                 AND table_name = 'task'
                 AND column_name = 'locked'));
END $$;