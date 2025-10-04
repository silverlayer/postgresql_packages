/*
 * Setup for database management module (pgmana)
 * You must run this script with a superuser account.
 * 
 * Authors: Kelvin S. Amorim <developers@silverlayer.space>
 * Designed for: PostgreSQL 8.4.x
 * Dependencies: plpgsql
 * License: BSD 3-Clause
 * Official repository: https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_mana
 */

set search_path to public;

-- FUNCTIONS SECTION

-- Idle sessions
create or replace function kill_idle(duration interval default '15 minutes')
returns void
language plpgsql as
$$
begin
	perform pg_terminate_backend(procpid) from pg_stat_activity
	where waiting=false
	and current_query in ('<IDLE>','<IDLE> in transaction')
	and (current_timestamp-query_start) >= duration;
end;
$$;

comment on function kill_idle(interval) is
'Terminates backends with idle sessions greater than or equal to "duration".
Parameters:
	duration - threshold for idle session time (default 15 minutes)
';

revoke all on function kill_idle(interval) from public;


-- Move indexes
create or replace function get_mvidx_stmt(dst_tbs text)
returns setof text
language plpgsql as
$$
begin
	if not exists(select true from pg_tablespace where spcname=dst_tbs) then
		raise exception 'The specified tablespace "%" does not exist',dst_tbs;
	end if;
	
	return query
	select 'alter index "'||s.nspname||'"."'||c.relname||'" set tablespace "'||dst_tbs||'";'
	from pg_class c join pg_namespace s on (c.relnamespace=s.oid)
	where c.relkind='i' and s.nspname not in ('pg_toast','pg_catalog')
	and c.reltablespace=0;

end;
$$;

comment on function get_mvidx_stmt(text) is 
'Returns statements to move indexes from the default tablespace to the specified tablespace.
Parameters:
	dst_tbs - target tablespace';


-- VIEWS SECTION

-- casts
create or replace view all_casts(source_type,target_type,context,"method","function") as
select src.typname,tgt.typname,castcontext,castmethod,
n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')'
from pg_cast
join pg_type src on pg_cast.castsource=src.oid
join pg_type tgt on pg_cast.casttarget=tgt.oid
left join pg_proc p on pg_cast.castfunc=p.oid
left join pg_namespace n on p.pronamespace=n.oid;

comment on view all_casts is
'Lists all casts in the database and its corresponding functions if any.
See the meaning of attributes at pg_cast documentation (https://www.postgresql.org/docs/8.4/catalog-pg-cast.html)';

comment on column all_casts.context is 'It is pg_cast.castcontext attribute';
comment on column all_casts."method" is 'It is pg_cast.castmethod attribute';


-- Schema size

create view schema_size(name,size) as
select s.nspname,sum(pg_relation_size(c.oid))
from pg_class c
join pg_namespace s on (c.relnamespace=s.oid)
group by s.nspname;

comment on view schema_size is 'Lists the total size of schemas. It considers all objects in the schema.';
comment on column schema_size.name is 'schema name';
comment on column schema_size.size is 'size of schema (bytes)';


-- Change objects ownership
create or replace view ownership_rectification_stmt(statement)
as
-- change table owner
select 'alter table "'||t.schemaname||'"."'||t.tablename||'" owner to "'||t.schemaname||'";'
from pg_tables t
where t.schemaname in (
	select n.nspname
	from pg_namespace n
	join pg_authid a on (n.nspname=a.rolname)
	where n.nspname not in ('information_schema','public')
	and n.nspname not like 'pg_%' and n.nspowner!=a.oid
)
union all -- change view owner
select 'alter view "'||v.schemaname||'"."'||v.viewname||'" owner to "'||v.schemaname||'";'
from pg_views v
where v.schemaname in (
	select n.nspname
	from pg_namespace n
	join pg_authid a on (n.nspname=a.rolname)
	where n.nspname not in ('information_schema','public')
	and n.nspname not like 'pg_%' and n.nspowner!=a.oid
)
union all -- change sequence owner
select 'alter sequence "'||n.nspname||'"."'||c.relname||'" owner to "'||n.nspname||'";'
from pg_class c 
join pg_namespace n on (c.relnamespace=n.oid)
join pg_authid a on (n.nspname=a.rolname)
where n.nspname not in ('information_schema','public')
and n.nspowner!=a.oid and c.relkind='S'
and n.nspname not like 'pg_%'
union all -- change function owner
select 'alter function "'||n.nspname||'"."'||f.proname||'"('||pg_get_function_identity_arguments(f.oid)||') owner to "'||n.nspname||'";'
from pg_proc f
join pg_namespace n on (f.pronamespace=n.oid)
join pg_authid a on (n.nspname=a.rolname)
where n.nspname not in ('information_schema','public')
and n.nspowner!=a.oid and n.nspname not like 'pg_%'
union all -- set privilege on tables
select distinct 'grant select on "'||vt.table_schema||'"."'||vt.table_name||'" to "'||vt.view_schema||'";'
from information_schema.view_table_usage vt
where vt.view_schema!=vt.table_schema
and vt.view_schema in (
	select n.nspname
	from pg_namespace n
	join pg_authid a on (n.nspname=a.rolname)
	where n.nspname not in ('information_schema','public')
	and n.nspname not like 'pg_%' and n.nspowner!=a.oid
)
union all -- change schema owner
select 'alter schema "'||n.nspname||'" owner to "'||n.nspname||'";'
from pg_namespace n
join pg_authid a on (n.nspname=a.rolname)
where n.nspname not in ('information_schema','public')
and n.nspname not like 'pg_%' and n.nspowner!=a.oid;

comment on view ownership_rectification_stmt is
'Generates statements to correct ownership of objects for environments wherein each user has its own schema with the same name (user-specific schema)';