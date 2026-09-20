# PgWeaver v0.2.0

PgWeaver is based on the concept of directed graph to compose the mesh of inter-dependency between schemas. Graphically, the schemas are connected to each other by directed arrows, where the arrowhead indicates the dependency and the origin of the arrow indicates the dependent. For instance, **A** &rarr; **B** should be read as **A** depends on **B** and **B** is a dependency of **A**. A schema cannot be dependent on itself.

The concepts of in-degree and out-degree were adapted to *dependent_degree* and *dependency_degree*, respectively. *dependent_degree* and *dependency_degree* are natural numbers, and every schema has a pair of these elements. A schema is called a **leaf schema** (leaf vertex) when its *dependency_degree* is equal to zero.

PgWeaver uses a cache table to store data, such a table is initially loaded by the `reload_cache` function. All other functions implicitly invoke `reload_cache`, so it is not necessary to invoke it beforehand. However, it is possible to force a reload.

## Installation & Uninstallation

Make sure the **plpgsql** is activated in the target database, and then execute the *pgweaver.sql* file as superuser. The module's objects are installed in the **public** schema by default. Run the *pgweaver_uninstall.sql* file to uninstall.


## Functions

`reload_cache(forced boolean)` &rarr; `void`

Creates the cache table with all inter-schema dependencies.

> :warning: This function takes a long time to execute at the first time or when **forced** is true.

**Parameters:**
- forced - if true, reloads the cache table even if it already exists (default false)

&nbsp;

`rm_dependents(variadic schemas text[])` &rarr; `integer`

Removes dependent schemas from cache table created by **reload_cache** function.

**Parameters:**
- schemas - array of dependent schemas to remove

**Returns:**
- amount of rows deleted

&nbsp;

`schema_degree(schema_name text)` &rarr; `table(int4, int4)`

Gets the dependent and dependency degree of the specified schema

**Parameters:**
- schema_name - name of the schema

**Returns:**
- A row like a vector of <dependent_degree, dependency_degree>

&nbsp;

`leaf_schemas(void)` &rarr; `setof text`

Lists all the leaf-schemas in the database. It is analogous to the leaf-vertex of graphs

**Returns:**
- A set of leaf-schemas

&nbsp;

`dependency_graph(schema_name text, depth int2)` &rarr; `text`

Creates a simple graph, in DOT language, with all schema dependencies of the given schema.


**Parameters:**
- schema_name - name of the schema
- depth - how deep the algorithm goes. It must be greater than zero (default 3)

**Returns:**
- A graph in DOT language when dependency_degree of the given schema is greater than zero. Otherwise, it returns NULL.
