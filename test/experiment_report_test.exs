defmodule ExAbby.ExperimentReportTest do
  use ExUnit.Case, async: true

  alias ExAbby.{Experiment, ExperimentReport, Variation}

  @now ~U[2026-09-01 12:00:00Z]

  defp experiment(overrides \\ []) do
    struct!(
      %Experiment{
        id: 1,
        name: "home_price",
        inserted_at: ~N[2026-08-11 00:00:00],
        variations: [
          %Variation{id: 1, name: "control", weight: 0.5},
          %Variation{id: 2, name: "bold", weight: 0.5}
        ]
      },
      overrides
    )
  end

  defp row(id, name, trials, unique1, opts \\ []) do
    excluded = Keyword.get(opts, :excluded, 0)
    unique2 = Keyword.get(opts, :unique2, 0)
    amount2 = Keyword.get(opts, :amount2, 0.0)

    %{
      variation_id: id,
      variation_name: name,
      trials: trials,
      excluded_trials: excluded,
      success1: %{
        count: unique1,
        unique_count: unique1,
        amount: 0.0,
        rate: 0.0,
        amount_per_trial: 0.0
      },
      success2: %{
        count: unique2,
        unique_count: unique2,
        amount: amount2,
        rate: 0.0,
        amount_per_trial: 0.0
      }
    }
  end

  test "picks the lowest-p comparison as best and names the winner" do
    report =
      ExperimentReport.from_summary(
        experiment(),
        [row(1, "control", 1000, 100), row(2, "bold", 1000, 200)],
        @now
      )

    assert report.metrics == [:success1]
    assert report.best.variation_name == "bold"
    assert report.best.significant?
    assert report.winners == %{success1: "bold"}
    assert report.health == :healthy
    assert report.running_days == 21
    assert report.totals.trials == 2000
    assert report.totals.success1.unique_count == 300
  end

  test "control wins a metric when the treatment is significantly worse" do
    report =
      ExperimentReport.from_summary(
        experiment(),
        [row(1, "control", 1000, 200), row(2, "bold", 1000, 100)],
        @now
      )

    assert report.winners == %{success1: "control"}
  end

  test "shows the second metric when it has a label or conversions" do
    labelled = experiment(success2_label: "Payment")
    summary = [row(1, "control", 1000, 100), row(2, "bold", 1000, 120)]

    assert ExperimentReport.from_summary(labelled, summary, @now).metrics ==
             [:success1, :success2]

    with_conversions = [row(1, "control", 1000, 100), row(2, "bold", 1000, 120, unique2: 3)]

    assert ExperimentReport.from_summary(experiment(), with_conversions, @now).metrics ==
             [:success1, :success2]
  end

  test "flags low traffic, high exclusion and skewed splits" do
    low =
      ExperimentReport.from_summary(
        experiment(),
        [row(1, "control", 40, 4), row(2, "bold", 40, 4)],
        @now
      )

    assert low.health == :low_traffic

    excluded =
      ExperimentReport.from_summary(
        experiment(),
        [row(1, "control", 500, 50, excluded: 100), row(2, "bold", 500, 50, excluded: 100)],
        @now
      )

    assert excluded.health == :high_exclusion

    skewed =
      ExperimentReport.from_summary(
        experiment(),
        [row(1, "control", 800, 80), row(2, "bold", 200, 20)],
        @now
      )

    assert skewed.health == :skewed_split
  end

  test "measures running time from the start time and stops at archival" do
    started = experiment(start_time: "08/22/2026 12:00AM")

    assert ExperimentReport.from_summary(started, [row(1, "control", 10, 1)], @now).running_days ==
             10

    archived = experiment(archived_at: ~U[2026-08-16 00:00:00Z])

    assert ExperimentReport.from_summary(archived, [row(1, "control", 10, 1)], @now).running_days ==
             5
  end

  test "reports missing control without comparisons" do
    no_control = experiment(variations: [%Variation{id: 1, name: "a", weight: 1.0}])
    report = ExperimentReport.from_summary(no_control, [row(1, "a", 1000, 100)], @now)

    assert report.significance == {:error, :control_not_found}
    assert report.best == nil
    assert ExperimentReport.comparison(report, :success1, 1) == :unavailable
    assert ExperimentReport.ready_comparisons(report) == []
  end

  test "comparison cells distinguish control, no data and ready comparisons" do
    report =
      ExperimentReport.from_summary(
        experiment(
          variations: experiment().variations ++ [%Variation{id: 3, name: "new", weight: 0.0}]
        ),
        [row(1, "control", 1000, 100), row(2, "bold", 1000, 120), row(3, "new", 0, 0)],
        @now
      )

    assert ExperimentReport.comparison(report, :success1, 1) == :control
    assert ExperimentReport.comparison(report, :success1, 3) == :no_data
    assert %{p_value: _} = ExperimentReport.comparison(report, :success1, 2)
    assert ExperimentReport.lift_scale(ExperimentReport.ready_comparisons(report)) in [5.0, 10.0]
    assert ExperimentReport.lift_scale([]) == nil
  end
end
