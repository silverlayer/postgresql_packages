# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [0.2.0] - 2025-10-25
### Changed
- The `kill_idle` function considers only backends with state *<IDLE> in transaction*.

### Fixed
- The `schema_size` view was fixed to show the correct size of schemas.