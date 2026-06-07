# Management Module - pgmana v0.5.0

This module's aim is to streamline administrative tasks commonly performed by DBAs in **PostgreSQL v8.4.x**.
It requires **plpgsql** to work correctly.


## Installation & Uninstallation

Make sure the **plpgsql** is activated in the target database, and then execute the *pgmana.sql* file as superuser. The module's objects are installed in the **public** schema by default. Run the *pgmana_uninstall.sql* file to uninstall.

## Functions

`kill_idle(duration interval)` &rarr; `void`

Terminates *idle in transaction* backends whose session time is greater than or equal to **duration**. Only superusers can execute it.

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
See the meaning of attributes at [pg_cast](https://www.postgresql.org/docs/8.4/catalog-pg-cast.html) documentation

**Attributes:**
- oid - the cast identification
- source_type - the type in the source of cast
- target_type - the type in the target of cast
- context - it is pg_cast.castcontext attribute
- method - it is pg_cast.castmethod attribute
- function - the function utilized for casting if any

&nbsp;

`all_operators`

Lists all operators in the database.
See the meaning of attributes at [pg_operator](https://www.postgresql.org/docs/8.4/catalog-pg-operator.html) documentation

**Attributes:**
- oid - the operator identification
- kind - it's based on pg_operator.oprkind attribute
- operator - the operator name
- commutator - name of commutator operator
- negator - name of negator operator
- left_type - the left operand type if any
- right_type - the right operand type if any
- result_type - it's based on pg_operator.oprresult attribute
- function - the function that compares the operands
- restriction_function - it's based on pg_operator.oprrest attribute
- join_function - it's based on pg_operator.oprjoin attribute
- is_mergeable - is the operator mergeable?
- is_hashable - is the operator hashable?
- owner - the operator's owner

&nbsp;

`schema_size`

Lists the total size of schemas. It considers all objects in the schema, except **large objects**.

**Attributes:**
- name - schema's name
- size - size of schema (bytes)

&nbsp;

`ownership_rectification_stmt`

Generates statements to correct ownership of objects for environments wherein each user has its own schema with the same name (user-specific schema)

**Attributes:**
- statement - command to change the ownership

&nbsp;

`db_objects`

Lists all objects (or relations) in the current database and their characteristics

**Attributes**
- oid - object's identity
- name - object's name
- type - object's type
- size - object's size (in bytes)
- tablespace - object's tablespace
- tablespace_loc - file system path of the tablespace
- relfilenode - file node identity of object

&nbsp;

`repeated_indexes`

Lists all repeated indexes in the current database. The index must be valid.

**Attributes**
- indexes_names - names of repeated indexes (as array)
- table_name - table's name
- columns_id - columns identities used by the indexes
- index_size - index's size (in bytes)
- rep_amount - amount of repetitions

&nbsp;

`unused_indexes`

Lists all unused indexes in the current database. It disregards primary, unique or invalid indexes.

**Attributes**
- table_name - table's name
- index_name - index's name
- index_size - index's size (in bytes)

&nbsp;

`largeobject_owner`

Lists all user-space columns that likely hold a reference to large objects.

**Attributes**
- schema - the schema name
- table_oid - table identification
- table - table name
- column - column name