# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2026-09-22
### Added
- `kill_idle_txn` function.
- `kill_idle_sess` function.

### Fixed
- Using "quote_ident" in `get_mvidx_stmt` function.

### Removed
- The `kill_idle` function.

## [0.5.2] - 2026-09-20
### Fixed
- Using the "quote_ident" function in queries that refer to object names.

## [0.5.1] - 2026-06-14
### Fixed
- The context field in all_casts view, it was showing wrong values.

## [0.5.0] - 2026-06-07
### Changed
- The SQL query of `all_casts` view was refactored.
- The SQL query of `kill_idle` function was refactored.

### Added
- The column `oid` in `all_casts` view.
- The `all_operators` view.
- The `largeobject_owner` view.

## [0.4.0] - 2025-11-26
### Changed
- The SQL query of `repeated_indexes` view was refactored.

### Added
- The column `index_size` was added in `repeated_indexes` view.

## [0.3.0] - 2025-11-24
### Added
- `db_objects, repeated_indexes` and `unused_indexes` views.

## [0.2.0] - 2025-10-25
### Changed
- The `kill_idle` function considers only backends with state *<IDLE> in transaction*.

### Fixed
- The `schema_size` view was fixed to show the correct size of schemas.