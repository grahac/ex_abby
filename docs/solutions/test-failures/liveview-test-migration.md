---
module: example_app experiment significance admin
date: 2026-09-10
problem_type: test_failure
component: testing_framework
severity: medium
symptoms:
  - "CI failed the experiment-significance LiveView tests after the admin UI refactor."
  - "Assertions looked for removed selectors and copy such as `P vs control` and `p-value-significant`."
  - "Phoenix LiveView 1.2 test helpers raised a runtime error requiring `lazy_html`."
root_cause: wrong_api
resolution_type: dependency_update
framework_version: "Phoenix LiveView 1.2.11"
related_components:
  - frontend
  - development_workflow
tags:
  - phoenix-liveview
  - liveview-testing
  - lazy-html
  - dependency-upgrade
  - example-app
---

# Phoenix LiveView test migration: update the helper and the DOM contract

## Problem

The example app's experiment-significance tests were written against the previous
admin page markup and component inputs. Updating the example app to current
Phoenix and LiveView versions also changed the LiveView test-helper requirement.

## Symptoms

The original suite reported five assertion failures because it searched for old
classes, labels, and methodology text. After the DOM assertions were corrected,
four tests stopped at `Phoenix.LiveViewTest.DOM.ensure_loaded!/0` with:
`Phoenix LiveView requires lazy_html as a test dependency.`

## What Didn't Work

Keeping the old selectors and copy would have made the tests describe a page that
no longer exists. Updating only the lockfile also left the example app pinned to
LiveView 1.0.18, so the LiveView advisory remained and the newer test helper could
not be used. The component fixture likewise could not keep passing the old
individual summary assigns after `ExperimentShowLive` began consuming an
`ExperimentReport`.

## Solution

Keep the example app's framework constraints aligned with the library's supported
stack and add the test-only parser required by LiveView 1.2:

```elixir
{:phoenix, "~> 1.8.0"},
{:phoenix_live_view, "~> 1.2.0"},
{:lazy_html, ">= 0.1.0", only: :test},
{:phoenix_live_dashboard, "~> 0.9.0"}
```

Refresh the lockfile, then make assertions follow the rendered DOM contract. The
current component renders `Lift vs control` and uses classes such as
`ex-abby-significant` and `ex-abby-show__weight-input`
(`lib/ex_abby/live/experiment_show_live.ex:447-465`). The test now asserts those
stable semantic classes and current copy (`example_app/test/ex_abby/experiment_significance_live_test.exs:28-48`).

For direct component tests, build the same report shape as production instead of
reconstructing its former assigns:

```elixir
report = ExperimentReport.from_summary(experiment, summary, now)

render_component(&ExperimentShowLive.render/1,
  report: report,
  experiment: report.experiment,
  start_time: nil,
  end_time: nil,
  from_to_error_message: nil,
  updated?: false
)
```

`ExperimentShowLive` loads and assigns an `ExperimentReport` in production
(`lib/ex_abby/live/experiment_show_live.ex:657-666`), and the report constructor
is defined at `lib/ex_abby/experiment_report.ex:44-79`.

## Why This Works

The failure had two independent causes. The tests had drifted from the current
LiveView DOM and render-input contract, while the framework upgrade introduced a
test parser that was not declared by the example app. Aligning the dependency
constraints and adding `lazy_html` fixes the test environment; asserting semantic
classes and constructing the current report read model fixes the test contract.

The migration was verified in PR #15: the root suite passed 123 tests, the
example app passed 38 tests, both Hex audits reported no advisories, and all
hosted CI checks passed before merge.

## Prevention

- Treat LiveView test selectors as part of the rendered component contract. Prefer
  semantic, component-owned classes over incidental generic tags or obsolete copy.
- When a LiveView component is refactored around a read model or report struct,
  update direct `render_component/2` fixtures to use the public constructor.
- When upgrading LiveView, check its test-helper requirements and keep parser
  dependencies in the test-only dependency list.
- Run both application suites, `mix compile --warnings-as-errors`,
  `mix format --check-formatted`, and `mix hex.audit` in default and production
  environments before merging a framework upgrade.
