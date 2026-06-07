/*
 * Uninstall database management module (pgmana)
 * You must run this script with a superuser account.
 * 
 * Authors: Kelvin S. Amorim <developers@silverlayer.space>
 * Official repository: https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_mana
 */

set search_path to public;

drop function if exists kill_idle(interval);
drop function if exists get_mvidx_stmt(text);
drop view if exists ownership_rectification_stmt;
drop view if exists all_casts;
drop view if exists schema_size;
drop view if exists db_objects;
drop view if exists repeated_indexes;
drop view if exists unused_indexes;
drop view if exists largeobject_owner;
drop view if exists all_operators;