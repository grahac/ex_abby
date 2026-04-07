# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] - 2026-04-06

### Fixed
- Redirect from `/ex_abby` now uses an absolute path derived from the request URI, fixing `push_navigate` errors when mounted under a scope
- Migration only adds column if it does not already exist
- Fixed bug where `/ex_abby` was breaking local links
- Fixed bug where `record_success` was adding trials when it shouldn't
- Fixed crash when variation or experiment names were not seeded (now warns instead)
- Fixed bug where entering "0" for weights did not work
- Fixed bug where second success rate was showing first success rate
- Fixed experiment dashboard rate calculation using wrong value
- Changed `drop_table` to `drop_if_exists` in migrations

### Added
- Archive support (v0.2)
- Support to start experiment with user object, integer, or string
- `set_experiment` function to set an experiment to a specific variation
- Ability to view trials from different time periods
- Page titles to admin pages
- Links to trials and back to experiment list
- `save_session_data` API function
- Redirect from `/ex_abby` root to index page

### Changed
- Updated LiveView dependency from 0.18 to 1.0
- Renamed `.exabby` to `ex_abby`
- Changed formatting of trial count display
- Improved handling when experiment does not exist

[Unreleased]: https://github.com/grahac/ex_abby/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/grahac/ex_abby/compare/3e00820...v0.2.2
