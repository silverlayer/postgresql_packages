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
	perform pg_terminate_backend(procpid)
	from pg_stat_activity
	where waiting=false
	and current_query='<IDLE> in transaction'
	and (clock_timestamp()-query_start) >= duration;
end;
$$;

comment on function kill_idle(interval) is
'Terminates "idle in transaction" backends whose session time is greater than or equal to "duration".
Parameters:
	duration - threshold for idle session time (default 15 minutes)

This function is part of pgmana module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_mana';

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
	dst_tbs - target tablespace

This function is part of pgmana module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_mana';


-- VIEWS SECTION

-- casts
create or replace view all_casts(oid,source_type,target_type,context,"method","function") as
select oid, castsource::regtype, casttarget::regtype,
case castcontext
	when 'e' then 'explicit'
	when 'i' then 'implicit in assignment'
	else 'implicit in expression'
end,
case castmethod
	when 'f' then 'function'
	when 'i' then 'I/O function'
	else 'no conversion'
end,
castfunc::regprocedure
from pg_cast;

comment on view all_casts is
'Lists all casts in the database and its corresponding functions if any.
See the meaning of attributes at pg_cast documentation (https://www.postgresql.org/docs/8.4/catalog-pg-cast.html)

This view is part of pgmana module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_mana';


-- operators
create or replace view all_operators("oid","kind","operator","commutator","negator","left_type","right_type","result_type","function","restriction_function","join_function","is_mergeable","is_hashable","owner") as
select o.oid,
case o.oprkind
	when 'b' then 'infix'
	when 'l' then 'prefix'
	when 'r' then 'postfix'
	else 'unknown'
end,
o.oid::regoper, o.oprcom::regoper, o.oprnegate::regoper, o.oprleft::regtype, o.oprright::regtype,
o.oprresult::regtype, o.oprcode::regprocedure, o.oprrest::regprocedure, o.oprjoin::regprocedure,
o.oprcanmerge, o.oprcanhash, a.rolname
from pg_operator o
join pg_authid a on (o.oprowner=a.oid);

comment on view all_operators is
'Lists all operators in the database.
See the meaning of attributes at pg_operator documentation (https://www.postgresql.org/docs/8.4/catalog-pg-operator.html)

This view is part of pgmana module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_mana';

-- Schema size

create or replace view schema_size(name,size) as
select s.nspname,sum(pg_total_relation_size(c.oid))
from pg_class c
join pg_namespace s on (c.relnamespace=s.oid)
where c.relkind='r'
group by s.nspname;

comment on view schema_size is
'Lists the total size of schemas. It considers all objects in the schema.

This view is part of pgmana module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_mana';
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
'Generates statements to correct ownership of objects for environments wherein each user has its own schema with the same name (user-specific schema)

This view is part of pgmana module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_mana';


create or replace view db_objects("oid","name","type","size","tablespace","tablespace_loc","relfilenode") as
select c.oid,n.nspname||'.'||c.relname,
case c.relkind
	when 'r' then 'table'
	when 'i' then 'index'
	when 'S' then 'sequence'
	when 'v' then 'view'
	when 'c' then 'composite type'
	when 't' then 'toast table'
	else 'unknown'
end,
pg_relation_size(c.oid),
ts.spcname,ts.spclocation,c.relfilenode
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on (c.relnamespace=n.oid)
join (
	select spcname,spclocation,
	case
		when oid=(select dattablespace from pg_catalog.pg_database where datname = current_database()) then 0
		else oid
	end as "oid"
	from pg_catalog.pg_tablespace
) ts on (c.reltablespace=ts.oid);

comment on view db_objects is
'Lists all objects (or relations) in the current database and their characteristics

This view is part of pgmana module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_mana';
comment on column db_objects.tablespace_loc is 'file system path of the tablespace';
comment on column db_objects.size is 'object size (in bytes)';


create or replace view repeated_indexes("indexes_names","table_name","columns_id","index_size","rep_amount") as
select array_agg(i.indexrelid::regclass::name),i.indrelid::regclass::name,i.indkey,
pg_relation_size(max(i.indexrelid)),count(1)
from pg_catalog.pg_index i
join pg_catalog.pg_class c on (i.indexrelid=c.oid)
where i.indisvalid
group by i.indrelid,i.indkey,i.indoption,c.relam
having count(1)>1;

comment on view repeated_indexes is
'Lists all repeated indexes in the current database

This view is part of pgmana module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_mana';
comment on column repeated_indexes.indexes_names is 'the names of repeated indexes (as array)';
comment on column repeated_indexes.columns_id is 'columns identities used by the indexes';
comment on column repeated_indexes.index_size is '(in bytes)';
comment on column repeated_indexes.rep_amount is 'amount of repetitions';


create or replace view unused_indexes("table_name","index_name","index_size") as
select schemaname||'.'||relname, indexrelname,pg_relation_size(indexrelid)
from pg_stat_user_indexes
join pg_index using (indexrelid)
where idx_scan<1
and indisvalid and not (indisprimary or indisunique);

comment on view unused_indexes is
'Lists all unused indexes in the current database

This view is part of pgmana module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_mana';
comment on column unused_indexes.index_size is '(in bytes)';


create or replace view largeobject_owner("schema","table_oid","table","column") as
select n.nspname, c.oid, c.relname, a.attname
from pg_class c
join pg_attribute a on (a.attrelid=c.oid)
join pg_namespace n on (n.oid=c.relnamespace)
where n.nspname not in ('pg_catalog','information_schema')
and c.relkind='r'
and a.atttypid='oid'::regtype
and a.attnum>0; -- exclude system columns

comment on view largeobject_owner is
'Lists all user-space columns that likely hold a reference to large objects

This view is part of pgmana module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_mana';