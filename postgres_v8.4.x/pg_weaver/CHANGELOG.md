# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-09-20
### Added
- `pgweaver_cache` internal table
- `reload_cache` function
- `rm_dependents` function

### Changed
- Speed optimization in the query that loads the internal cache table.

### Removed
- `remove_dependents` function
- `cache_dependency` function
- `dependency` view
