/*
 * Setup for pg_weaver module
 * You must run this script with a superuser account.
 * 
 * Authors: Kelvin S. Amorim <kelvin.amorim@proton.me>
 * Designed for: PostgreSQL 8.4.x
 * Dependencies: plpgsql
 * License: BSD 3-Clause
 * Official repository: https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_weaver
 */

set search_path to public;

create or replace function reload_cache(forced boolean default false)
returns void
language plpgsql as
$$
begin

	if forced then
		drop table if exists pgweaver_cache;
	end if;

	begin
		if exists(select 1 from pgweaver_cache limit 1) then
			return;
		end if;
	exception when others then
		raise notice 'loading pgweaver_cache table ...';
	end;
	
	create table pgweaver_cache as
	select g_grantee.rolname::text as schema_dependent, nc.nspname::text as schema_dependency
	from pg_class c
	join pg_namespace nc on (c.relnamespace = nc.oid),
	pg_authid u_grantor, pg_authid g_grantee,
	(values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'),('TRIGGER')) pr(type)
	where c.relkind in ('r','v')
	and g_grantee.rolname not in ('postgres', nc.nspname)
	and aclcontains(c.relacl, makeaclitem(g_grantee.oid, u_grantor.oid, pr.type, false))
	and exists(select true from pg_namespace where nspname=g_grantee.rolname)
	union -- dependency on functions
	select g_grantee.rolname::text, n.nspname::text
	from pg_proc p
	join pg_namespace n on (p.pronamespace = n.oid),
	pg_authid u_grantor, pg_authid g_grantee
	where g_grantee.rolname not in ('postgres', n.nspname)
	and exists(select true from pg_namespace where nspname=g_grantee.rolname)
	and aclcontains(p.proacl, makeaclitem(g_grantee.oid, u_grantor.oid, 'EXECUTE', false))
	union -- views dependencies
	select view_schema::text,table_schema::text
	from information_schema.view_table_usage
	where view_schema not like 'pg_%'
	and view_schema not in ('information_schema', table_schema);

	comment on table pgweaver_cache is 'This table belongs to pgweaver module. pgweaver is available at https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_weaver';

end;
$$;

comment on function reload_cache(boolean) is
'Creates a table with all inter-schema dependencies
Parameters:
	forced - if true, reloads the cache table even if it already exists.

This function is part of pgweaver module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_weaver';

revoke all on function reload_cache(boolean) from public;

create or replace function rm_dependents(variadic schemas text[])
returns integer
language plpgsql as
$$
declare
	sch text;
	del integer := 0;
begin
	for sch in (select x from unnest(schemas) x) loop
		if sch is null or length(trim(sch))<=0 then
			raise exception '"schemas" cannot be empty';
		end if;
	end loop;
	
	perform reload_cache();
	select count(1)::int4 into del from pgweaver_cache where schema_dependent=any(schemas);
	delete from pgweaver_cache where schema_dependent=any(schemas);
	return del;
end;
$$;

comment on function rm_dependents(text[]) is
'Removes dependent schemas from cache table created by "reload_cache" function.
Parameters:
	schemas - array of dependent schemas to remove

Returns:
	amount of rows deleted

This function is part of pgweaver module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_weaver';

revoke all on function rm_dependents(text[]) from public;

create or replace function schema_degree(schema_name text)
returns table(dependent_degree int4, dependency_degree int4)
language plpgsql as
$$
begin
	if schema_name is null or length(trim(schema_name))<=0 then
		raise exception '"schema_name" cannot be empty';
	end if;
	
	perform reload_cache();
	
	return query
	select
	(select count(1)::int4 from pgweaver_cache where schema_dependency=schema_name),
	(select count(1)::int4 from pgweaver_cache where schema_dependent=schema_name);

end;
$$;

comment on function schema_degree(text) is
'Gets the dependent and dependency degree of the specified schema
Parameters:
	schema_name - name of the schema

Returns:
	A row like a vector of <dependent_degree, dependency_degree>

This function is part of pgweaver module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_weaver';

create or replace function leaf_schemas()
returns setof text
language plpgsql as
$$
begin
	perform reload_cache();

	return query
	select distinct a.schema_dependency
	from pgweaver_cache a
	where not exists(
		select true from pgweaver_cache
		where schema_dependent=a.schema_dependency
	)
	order by a.schema_dependency;
end;
$$;

comment on function leaf_schemas() is
'Lists all the leaf-schemas in the database. It is analogous to the leaf-vertex of graphs
Returns:
	A set of leaf-schemas

This function is part of pgweaver module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_weaver';

create or replace function dependency_graph(schema_name text, depth int2 default 3)
returns text
language plpgsql as
$dgraph$
declare
	tgraph text;
begin
	if schema_name is null or length(trim(schema_name))<=0 then
		raise exception '"schema_name" cannot be empty';
	end if;
	
	if depth <= 0 then
		raise exception '"depth" must be greater than zero';
	end if;

	perform reload_cache();
	
	with recursive trail(schema_dependent,schema_dependency,deep,path,cic) as
	(
		select schema_dependent,schema_dependency,1,array[schema_dependent],false
		from pgweaver_cache
		where schema_dependent=schema_name
		union all
		select dc.schema_dependent,dc.schema_dependency,
		tp.deep+1,path||dc.schema_dependent,
		dc.schema_dependent=any(path) -- is cyclic?
		from trail tp
		join pgweaver_cache dc on (tp.schema_dependency=dc.schema_dependent)
		where not cic
	),
	deduplicated as (
		select distinct schema_dependent,schema_dependency
		from trail where deep<=depth
	)
	select
	'digraph dependency {
	ratio=fill;
	overlap=scale;
	node [shape=box];
	"'||schema_name||'" [style=filled,fillcolor=green];
	'||array_to_string(array_agg('"'||schema_dependent||'" -> "'||schema_dependency||'";'||chr(10)), chr(9))||'}'
	into tgraph
	from deduplicated;

	return tgraph;
end;
$dgraph$;

comment on function dependency_graph(text, int2) is
'Creates a simple graph, in DOT language, with all schema dependencies of the given schema.
Parameters:
	schema_name - name of the schema
	depth - how deep the algorithm goes. It must be greater than zero

Returns:
	A graph in DOT language when dependency_degree of the given schema is greater than zero. Otherwise, it returns NULL.

This function is part of pgweaver module
https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_weaver';

revoke all on function dependency_graph(text, int2) from public;
