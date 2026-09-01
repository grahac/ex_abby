defmodule ExAbby.Live.ExperimentShowLiveTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias ExAbby.{Experiment, ExperimentReport, Variation}
  alias ExAbby.Live.ExperimentShowLive

  defp assigns(report) do
    %{
      report: report,
      experiment: report.experiment,
      start_time: nil,
      end_time: nil,
      from_to_error_message: nil,
      updated?: false
    }
  end

  test "names the winner in the headline and highlights the leader row for a two-metric experiment" do
    experiment = %Experiment{
      id: 1,
      name: "home_price",
      description: "Homepage price test",
      inserted_at: ~N[2026-08-01 00:00:00],
      success1_label: "Signup",
      success2_label: "Payment",
      variations: [
        %Variation{id: 1, name: "control", weight: 0.5},
        %Variation{id: 2, name: "bold", weight: 0.5}
      ]
    }

    summary = [
      %{
        variation_id: 1,
        variation_name: "control",
        trials: 1000,
        excluded_trials: 0,
        success1: %{count: 100, unique_count: 100, amount: 0.0, rate: 0.1, amount_per_trial: 0.0},
        success2: %{count: 0, unique_count: 0, amount: 0.0, rate: 0.0, amount_per_trial: 0.0}
      },
      %{
        variation_id: 2,
        variation_name: "bold",
        trials: 1000,
        excluded_trials: 0,
        success1: %{count: 200, unique_count: 200, amount: 0.0, rate: 0.2, amount_per_trial: 0.0},
        success2: %{count: 0, unique_count: 0, amount: 0.0, rate: 0.0, amount_per_trial: 0.0}
      }
    ]

    report = ExperimentReport.from_summary(experiment, summary, DateTime.utc_now())
    assert report.winners.success1 == "bold"
    assert report.best.significant?

    html = render_component(&ExperimentShowLive.render/1, assigns(report))

    assert html =~ "bold"
    assert html =~ "ahead on"
    assert html =~ "ex-abby-row--leader"
  end

  test "shows the unavailable message when no variation is named control" do
    experiment = %Experiment{
      id: 2,
      name: "no_control_exp",
      description: "No control variation",
      inserted_at: ~N[2026-08-01 00:00:00],
      variations: [
        %Variation{id: 1, name: "alpha", weight: 0.5},
        %Variation{id: 2, name: "beta", weight: 0.5}
      ]
    }

    summary = [
      %{
        variation_id: 1,
        variation_name: "alpha",
        trials: 100,
        excluded_trials: 0,
        success1: %{count: 10, unique_count: 10, amount: 0.0, rate: 0.1, amount_per_trial: 0.0},
        success2: %{count: 0, unique_count: 0, amount: 0.0, rate: 0.0, amount_per_trial: 0.0}
      },
      %{
        variation_id: 2,
        variation_name: "beta",
        trials: 100,
        excluded_trials: 0,
        success1: %{count: 12, unique_count: 12, amount: 0.0, rate: 0.12, amount_per_trial: 0.0},
        success2: %{count: 0, unique_count: 0, amount: 0.0, rate: 0.0, amount_per_trial: 0.0}
      }
    ]

    report = ExperimentReport.from_summary(experiment, summary, DateTime.utc_now())
    assert report.significance == {:error, :control_not_found}

    html = render_component(&ExperimentShowLive.render/1, assigns(report))

    assert html =~ "Significance is unavailable"
    assert html =~ "control"
  end

  test "marks control as the leader when the treatment loses significantly" do
    experiment = %Experiment{
      id: 1,
      name: "home_price",
      inserted_at: ~N[2026-08-01 00:00:00],
      variations: [
        %Variation{id: 1, name: "control", weight: 0.5},
        %Variation{id: 2, name: "bold", weight: 0.5}
      ]
    }

    row = fn id, name, unique ->
      %{
        variation_id: id,
        variation_name: name,
        trials: 1000,
        excluded_trials: 0,
        success1: %{
          count: unique,
          unique_count: unique,
          amount: 0.0,
          rate: unique / 1000,
          amount_per_trial: 0.0
        },
        success2: %{count: 0, unique_count: 0, amount: 0.0, rate: 0.0, amount_per_trial: 0.0}
      }
    end

    report =
      ExperimentReport.from_summary(
        experiment,
        [row.(1, "control", 300), row.(2, "bold", 200)],
        DateTime.utc_now()
      )

    html = render_component(&ExperimentShowLive.render/1, assigns(report))

    assert report.winners.success1 == "control"

    assert html =~
             ~r/ex-abby-row--leader[^>]*>\s*<td[^>]*>\s*<input[^>]*weight_1\]/
  end
end
