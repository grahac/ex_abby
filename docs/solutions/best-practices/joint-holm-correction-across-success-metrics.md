---
title: Joint Holm correction across success metrics
date: 2026-08-28
category: best-practices
module: ExAbby.Statistics
problem_type: best_practice
component: service_layer
severity: medium
applies_when:
  - Any displayed success metric can identify a winning treatment
  - An experiment compares several treatments or success metrics with control
tags: [experimentation, holm-correction, multiple-testing, p-values, success-metrics]
---

# Joint Holm correction across success metrics

## Context

ExAbby originally applied Holm correction across treatment arms separately for
each success metric. That is appropriate when each metric is interpreted on its
own, but not when the product decision is “declare a winner if either metric is
significant.” The earlier implementation explicitly used separate families
(session history); the product decision later confirmed that either outcome may
identify a winner and neither outcome should be privileged as primary.

## Guidance

Build one correction family containing every requested
`{success metric, treatment}` comparison. Calculate each raw control-relative
p-value first, apply Holm once to the combined list, and then group the adjusted
results back by metric for display. `compare_metrics_to_control/3` implements
that shape and records both the metrics and total family size in its result
(`lib/ex_abby/statistics.ex:73`).

Call the joint API once from any surface that lets several metrics trigger the
same winner decision:

```elixir
{:ok, significance_by_metric} =
  ExAbby.Statistics.compare_metrics_to_control(
    summary,
    [:success1, :success2],
    control_name: "control"
  )
```

Do not call `compare_to_control/3` independently for each metric and then treat
either result as an experiment-wide win. The single-metric API remains useful
for callers making a decision about one metric; it delegates to the joint path
with a one-metric family (`lib/ex_abby/statistics.ex:53`). The results LiveView
requests both metrics together whenever the second outcome is displayed
(`lib/ex_abby/live/experiment_show_live.ex:542`).

## Why This Matters

Joint correction does **not** require both metrics to become significant. Each
adjusted comparison retains its own `significant?` result, so a treatment can win
on either success metric while the other remains non-significant. The combined
family only accounts for the fact that there are several opportunities to find
a winner.

Separate metric families answer two independent questions. Treating their union
as one product decision increases the chance that at least one green result
appears by chance. Holm correction across the combined family preserves the
experiment-wide false-positive contract while being less conservative than
requiring both outcomes to pass.

## When to Apply

- Apply this pattern when any of several success metrics can trigger the same
  winner, rollout, or stop decision.
- Keep a single-metric family when only one metric is used for the decision and
  the others are purely descriptive.
- Decide the requested metric family before interpreting results; adding a new
  decision metric after inspecting outcomes creates another selection problem.

## Examples

The statistics test constructs two treatments: one wins only on `success1`, and
the other wins only on `success2`. Both can be significant even though all four
treatment-by-metric comparisons are ranked in one family
(`test/ex_abby_statistics_test.exs:162`).

The database-backed LiveView test uses one treatment whose first metric matches
control while its second metric wins. The rendered adjusted p-value proves that
the page used the two-metric family rather than two separate calls
(`example_app/test/ex_abby/experiment_significance_live_test.exs:93`).

## Related

- [Choosing an inference model for experiment results](../../research/experiment-inference-methods.md)
- [Statistical significance](../../../README.md#statistical-significance)
