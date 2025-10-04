# Maintenance Module - pgmaint v0.1.0

The objective of this module is to facilitate maintenance tasks commonly performed by DBAs in **PostgreSQL v8.4.x**.
This module requires **plpgsql** and the **pgstattuple** module to work correctly.


## Installation & Uninstallation

Make sure the **pgstattuple** module is installed in the target database, and then execute the *pgmaint.sql* file as superuser. The module's functions are installed in the **public** schema by default. Run the *pgmaint_uninstall.sql* file to uninstall.

## Functions

`get_reindex_stmt(density numeric)` &rarr; `setof text`

Returns statements for reindexing of bloated indexes.
It searches for indexes whose **avg_leaf_density** is less than **density** parameter. Only superusers can execute it.

> :warning: This function takes a long time to execute, so avoid using it in busy production environments.

**Parameters:**
- density - must be between 80.0 and 96.0