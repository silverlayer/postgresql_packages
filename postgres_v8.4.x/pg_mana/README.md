# Management Module - pgmana v0.1.0

This module's aim is to streamline administrative tasks commonly performed by DBAs in **PostgreSQL v8.4.x**.
It requires **plpgsql** to work correctly.


## Installation & Uninstallation

Make sure the **plpgsql** is activated in the target database, and then execute the *pgmana.sql* file as superuser. The module's objects are installed in the **public** schema by default. Run the *pgmana_uninstall.sql* file to uninstall.

## Functions

`kill_idle(duration interval)` &rarr; `void`

Terminates backends with idle sessions greater than or equal to **duration**. Only superusers can execute it.

**Parameters:**
- duration - threshold for idle session time (default 15 minutes)

&nbsp;

`get_mvidx_stmt(dst_tbs text)` &rarr; `setof text`

Returns statements to move indexes from the default tablespace to the specified tablespace.

**Parameters:**
- dst_tbs - target tablespace


## Views

`all_casts`

Lists all casts in the database and its corresponding functions if any.
See the meaning of attributes at pg_cast documentation https://www.postgresql.org/docs/8.4/catalog-pg-cast.html

**Attributes:**
- source_type - the type in the source of cast
- target_type - the type in the target of cast
- context - it is pg_cast.castcontext attribute
- method - it is pg_cast.castmethod attribute
- function - the function utilized for casting if any

&nbsp;

`schema_size`

Lists the total size of schemas. It considers all objects in the schema.

**Attributes:**
- name - schema's name
- size - size of schema (bytes)

&nbsp;

`ownership_rectification_stmt`

Generates statements to correct ownership of objects for environments wherein each user has its own schema with the same name (user-specific schema)

**Attributes:**
- statement - command to change the ownership