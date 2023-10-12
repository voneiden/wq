-- Verify wq:0001_initial on pg

begin;
do $$
begin
    assert (select has_table_privilege('wq', 'task'));
end $$;
rollback;
