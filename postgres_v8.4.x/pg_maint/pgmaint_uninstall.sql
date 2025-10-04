/*
 * Uninstall database maintenance module (pgmaint)
 * You must run this script with a superuser account.
 * 
 * Authors: Kelvin S. Amorim <developers@silverlayer.space>
 * Official repository at: https://github.com/silverlayer/postgresql_packages/tree/main/postgres_v8.4.x/pg_maint
 */


set search_path to public;

drop function if exists get_reindex_stmt(numeric);