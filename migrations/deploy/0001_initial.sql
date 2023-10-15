-- Deploy wq:0001_initial to pg

BEGIN;

create table task (
  
  id serial PRIMARY KEY,
  
  title varchar(1000) NOT NULL,
  priority integer NOT NULL,
  
  deadline timestamptz,

  created_at timestamptz NOT NULL DEFAULT NOW()
);

COMMIT;
