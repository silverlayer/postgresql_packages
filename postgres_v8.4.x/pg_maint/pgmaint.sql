/*
 * Setup for database maintenance module (pgmaint).
 * You must run this script with a superuser account.
 * 
 * Authors: Kelvin S. Amorim <developers@silverlayer.space>
 * Designed for: PostgreSQL 8.4.x
 * Dependencies: pgstattuple module and plpgsql
 * License: BSD 3-Clause
 * Official repository: https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_maint
 */


set search_path to public;

-- Bloated indexes

create or replace function get_reindex_stmt(density numeric)
returns setof text
language plpgsql as
$$
begin
	if density < 80 or density > 96 then
		raise exception 'density parameter out of range';
	end if;

	return query
	select 'reindex index '||i.indexrelid::regclass::text||';'
	from pg_index i
	join pg_class c on (i.indexrelid = c.oid)
	join pg_namespace n on (c.relnamespace = n.oid)
	where n.nspname not in ('pg_catalog', 'pg_toast')
	and (pgstatindex(i.indexrelid::regclass::text)).avg_leaf_density::numeric < density
	and (pgstatindex(i.indexrelid::regclass::text)).leaf_fragmentation::numeric > 0
	and i.indisvalid=true;
end;
$$;

comment on function get_reindex_stmt(numeric) is
'Returns statements for reindexing of bloated indexes.
It searches for indexes whose "avg_leaf_density" is less than "density" parameter and "leaf_fragmentation" is greater than zero
Parameters:
	density - must be between 80.0 and 96.0';

revoke all on function get_reindex_stmt(numeric) from public;