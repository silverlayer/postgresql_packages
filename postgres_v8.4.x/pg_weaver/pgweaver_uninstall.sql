/*
 * Uninstall pg_weaver module
 * You must run this script with a superuser account.
 * 
 * Authors: Kelvin S. Amorim <developers@silverlayer.space>
 * Official repository: https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_weaver
 */


set search_path to public;

drop view if exists dependency;
drop function if exists cache_dependency(boolean);
drop function if exists remove_dependents(text[]);
drop function if exists schema_degree(text);
drop function if exists leaf_schemas();
drop function if exists dependency_graph(text,int2);