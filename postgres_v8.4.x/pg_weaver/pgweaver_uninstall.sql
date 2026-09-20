/*
 * Uninstall pg_weaver module
 * You must run this script with a superuser account.
 * 
 * Authors: Kelvin S. Amorim <kelvin.amorim@proton.me>
 * Official repository: https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_weaver
 */


set search_path to public;

drop table if exists pgweaver_cache;
drop function if exists reload_cache(boolean);
drop function if exists rm_dependents(text[]);
drop function if exists schema_degree(text);
drop function if exists leaf_schemas();
drop function if exists dependency_graph(text,int2);