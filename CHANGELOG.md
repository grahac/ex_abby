# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0] - 2026-10-17

### Changed
- Significance now uses an asymptotic confidence sequence on the difference in conversion rates (Waudby-Smith et al., 2024) instead of separate beta-binomial confidence sequences per arm. P-values are still safe to check at any time, but they no longer sit at 1.0 for any realistic lift: at a 1% base rate and 4,000 trials per arm, a doubled conversion rate now gives p ≈ 0.013 instead of 1.0. `compare_to_control/3` and `compare_metrics_to_control/3` report `method: :asymptotic_confidence_sequence`, and p-values and lift intervals change for existing experiments.

## [0.5.3] - 2026-10-16

### Security
- The trials page (`ExAbby.Live.TrialManagementLive`) now changes only the viewer's own trials: their session's, or their signed-in user's. Before, "update-variation" updated any trial id the client sent, so a public trials page let anyone rewrite other visitors' assignments. The variation must also belong to the trial's experiment.
- `?user_id=` on the trials page is honoured only on the admin mount; elsewhere it no longer shows another user's trials.

### Changed
- `ex_abby_admin_routes/1` mounts the trials page with the `:admin` live action, which keeps the admin's ability to view and edit any trial. A host that mounts `TrialManagementLive` directly (for example, as a hidden public page) gets the owner-only behaviour.

## [0.5.2] - 2026-10-13

### Fixed
- Load admin index reports asynchronously for the selected tab, so archived reports do not delay the initial Running view.
- Cancel superseded admin index report loads when switching tabs, so a stale load cannot overwrite the current tab.

### Changed
- The admin index's significant-results count applies to the selected tab; running and archived totals remain global.

## [0.5.1] - 2026-09-01

### Added
- `ExAbby.ExperimentReport`, a read model that combines experiment summaries with control-relative significance, per-metric winners, totals, running time and a health flag (low traffic, high exclusion rate, skewed split).

### Changed
- Redesigned the admin experiments list: running/significant/archived counts, name search, a Running/Archived/All filter, the best lift and p-value per experiment on a shared scale, a health column, running days and a recently archived panel.
- Redesigned the admin experiment results page: breadcrumb top bar, summary strip with a winner headline, an allocation table with per-metric rate and lift-versus-control cells, one panel per success metric, methodology notes and an inline archive row.
- Shared admin styles now use a warm cream and green palette with Instrument Sans and IBM Plex Mono font stacks.

## [0.5.0] - 2026-08-30

### Added
- Anytime-valid, Holm-adjusted p-values and lift confidence sequences comparing each treatment with the configured control variation in the admin experiment results view.

### Changed
- Reworked the optional LiveView admin screens with self-contained, accessible styles that do not depend on the host application's stylesheet.
- Condensed result-table success counts into clearly labeled total and unique values.

### Fixed
- Use LiveView navigation for links between separate admin LiveViews, and expose disclosure state and archive-control labels to assistive technology.

## [0.4.0] - 2026-07-28

### Added
- Default-on bot detection for request-aware controller and LiveView assignments, with configurable detector chains and a control fallback that does not create trials.
- Reversible trial exclusion and restoration APIs, excluded-trial reporting, and bot-assignment telemetry.
- Warning and `[:ex_abby, :bot_detector, :error]` telemetry when a configured detector fails; request data is not included in either signal.

### Fixed
- Existing variation weights are now updated correctly by both experiment upserts and `update_variation_weights/2`.

## [0.3.0] - 2026-06-28

### Added
- `ExAbby.Migrations.add_trial_uniqueness/1` and `remove_trial_uniqueness/1` — partial unique indexes on `(experiment_id, session_id)` and `(experiment_id, user_id)` that prevent duplicate trials. Supports `concurrently: true` for large production tables.
- `ExAbby.Migrations.deduplicate_trials/0` — merges duplicate trials (summing success counts/amounts onto the lowest-id row) so the uniqueness index can be added on databases that already contain duplicates.

### Fixed
- `get_or_create_session_trial/2` and `get_or_create_user_trial/2` are now race-safe. Concurrent requests for the same session/user no longer create duplicate trial rows or crash callers with `Ecto.MultipleResultsError`; the race loser re-reads the winner's row.
- `link_session_to_user/3` no longer raises `Ecto.ConstraintError` when the target user already has a trial for the experiment — it returns the user's existing trial instead.

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

[Unreleased]: https://github.com/grahac/ex_abby/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/grahac/ex_abby/compare/v0.5.3...v0.6.0
[0.5.3]: https://github.com/grahac/ex_abby/compare/v0.5.2...v0.5.3
[0.5.2]: https://github.com/grahac/ex_abby/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/grahac/ex_abby/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/grahac/ex_abby/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/grahac/ex_abby/compare/v0.3.0...v0.4.0
[0.2.2]: https://github.com/grahac/ex_abby/compare/3e00820...v0.2.2
