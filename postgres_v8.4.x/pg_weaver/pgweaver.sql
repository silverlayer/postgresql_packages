/*
 * Setup for pg_weaver module
 * You must run this script with a superuser account.
 * 
 * Authors: Kelvin S. Amorim <developers@silverlayer.space>
 * Designed for: PostgreSQL 8.4.x
 * Dependencies: plpgsql
 * License: BSD 3-Clause
 * Official repository: https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_weaver
 */


set search_path to public;

create or replace view dependency(schema_dependent, schema_dependency) as
select tg.grantee,tg.table_schema
from information_schema.role_table_grants tg
where tg.grantee!='postgres'
and tg.grantee!=tg.table_schema
and exists(select true from pg_namespace where nspname=tg.grantee)
union -- dependency on functions
select rg.grantee,rg.routine_schema
from information_schema.role_routine_grants rg
where rg.grantee!='postgres'
and rg.grantee!=rg.routine_schema
and exists(select true from pg_namespace where nspname=rg.grantee)
union -- views dependencies
select view_schema,table_schema
from information_schema.view_table_usage
where view_schema not like 'pg_%'
and view_schema!='information_schema'
and view_schema!=table_schema;

comment on view dependency is 'Lists all inter-schema dependencies';

revoke all on dependency from public;


create or replace function cache_dependency(force_reload boolean default false)
returns void
language plpgsql as
$$
begin

	if force_reload then
		drop table if exists dependency_cache;

		create temp table dependency_cache as
		select schema_dependent::text,schema_dependency::text
		from dependency
		order by schema_dependent,schema_dependency;

		return;
	end if;

	begin
		if exists(select 1 from dependency_cache limit 1) then
			return;
		end if;
	exception when others then
		raise notice 'loading...';
	end;
	
	create temp table dependency_cache as
	select schema_dependent::text,schema_dependency::text
	from dependency
	order by schema_dependent,schema_dependency;
end;
$$;


comment on function cache_dependency(boolean) is
'Creates a temporary table with all inter-schema dependencies
Parameters:
	force_reload - if true, reloads the temporary table even if it already exists.
';

revoke all on function cache_dependency(boolean) from public;

create or replace function remove_dependents(variadic schemas text[])
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
	
	perform cache_dependency();
	select count(1)::int4 into del from dependency_cache where schema_dependent=any(schemas);
	delete from dependency_cache where schema_dependent=any(schemas);
	return del;
end;
$$;

comment on function remove_dependents(text[]) is
'Removes dependent schemas from the temporary table created by "cache_dependency" function.
Parameters:
	schemas - array of dependent schemas to remove

Returns:
	amount of rows deleted
';

create or replace function schema_degree(schema_name text)
returns table(dependent_degree int4, dependency_degree int4)
language plpgsql as
$$
begin
	if schema_name is null or length(schema_name)<=0 then
		raise exception '"schema_name" cannot be empty';
	end if;
	
	perform cache_dependency();
	
	return query
	select
	(select count(1)::int4 from dependency_cache where schema_dependency=schema_name),
	(select count(1)::int4 from dependency_cache where schema_dependent=schema_name);

end;
$$;

comment on function schema_degree(text) is
'Gets the dependent and dependency degree of the specified schema
Parameters:
	schema_name - name of the schema

Returns:
	A row like a vector of <dependent_degree, dependency_degree>
';

create or replace function leaf_schemas()
returns setof text
language plpgsql as
$$
begin
	perform cache_dependency();

	return query
	select distinct a.schema_dependency
	from dependency_cache a
	where not exists(
		select 1 from dependency_cache
		where schema_dependent=a.schema_dependency
	)
	order by a.schema_dependency;
end;
$$;

comment on function leaf_schemas() is
'Lists all the leaf-schemas in the database. It is analogous to the leaf-vertex of graphs
Returns:
	A set of leaf-schemas
';

create or replace function dependency_graph(schema_name text, depth int2 default 3)
returns text
language plpgsql as
$dgraph$
declare
	tgraph text;
begin
	if schema_name is null or length(schema_name)<=0 then
		raise exception '"schema_name" cannot be empty';
	end if;
	
	if depth <= 0 then
		raise exception '"depth" must be greater than zero';
	end if;

	perform cache_dependency();
	
	with recursive trail(schema_dependent,schema_dependency,deep,path,cic) as (
		select schema_dependent,schema_dependency,1,array[schema_dependent],false
		from dependency_cache
		where schema_dependent=schema_name
		union all
		select dc.schema_dependent,dc.schema_dependency,
		tp.deep+1,path||dc.schema_dependent,
		dc.schema_dependent=any(path) -- is cyclic?
		from trail tp
		join dependency_cache dc on (tp.schema_dependency=dc.schema_dependent)
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
';

