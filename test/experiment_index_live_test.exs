defmodule ExAbby.ExperimentIndexLiveTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias ExAbby.{Experiment, ExperimentReport, Variation}

  setup do
    Application.put_env(:ex_abby, :control_variation_name, "control")
    :ok
  end

  test "renders reports with a significant result, health status and running days" do
    winning_experiment =
      %Experiment{
        id: 1,
        name: "home_buy_now_price_v1",
        description: "Homepage hero: omit or show the membership starting price",
        inserted_at: ~N[2026-08-01 00:00:00],
        archived_at: nil,
        variations: [
          %Variation{id: 1, name: "control", weight: 0.5},
          %Variation{id: 2, name: "treatment", weight: 0.5}
        ]
      }

    winning_summary = [
      %{
        variation_id: 1,
        variation_name: "control",
        trials: 500,
        excluded_trials: 0,
        success1: %{count: 100, unique_count: 100, amount: 0.0, rate: 0.2, amount_per_trial: 0.0},
        success2: %{count: 0, unique_count: 0, amount: 0.0, rate: 0.0, amount_per_trial: 0.0}
      },
      %{
        variation_id: 2,
        variation_name: "treatment",
        trials: 500,
        excluded_trials: 0,
        success1: %{count: 250, unique_count: 250, amount: 0.0, rate: 0.5, amount_per_trial: 0.0},
        success2: %{count: 0, unique_count: 0, amount: 0.0, rate: 0.0, amount_per_trial: 0.0}
      }
    ]

    quiet_experiment =
      %Experiment{
        id: 2,
        name: "search_empty_state",
        description: "Suggested queries versus a plain no-results message",
        inserted_at: ~N[2026-08-05 00:00:00],
        archived_at: nil,
        variations: [
          %Variation{id: 3, name: "control", weight: 0.5},
          %Variation{id: 4, name: "treatment", weight: 0.5}
        ]
      }

    quiet_summary = [
      %{
        variation_id: 3,
        variation_name: "control",
        trials: 10,
        excluded_trials: 0,
        success1: %{count: 1, unique_count: 1, amount: 0.0, rate: 0.1, amount_per_trial: 0.0},
        success2: %{count: 0, unique_count: 0, amount: 0.0, rate: 0.0, amount_per_trial: 0.0}
      },
      %{
        variation_id: 4,
        variation_name: "treatment",
        trials: 10,
        excluded_trials: 0,
        success1: %{count: 2, unique_count: 2, amount: 0.0, rate: 0.2, amount_per_trial: 0.0},
        success2: %{count: 0, unique_count: 0, amount: 0.0, rate: 0.0, amount_per_trial: 0.0}
      }
    ]

    now = DateTime.from_naive!(~N[2026-08-22 00:00:00], "Etc/UTC")

    winning_report = ExperimentReport.from_summary(winning_experiment, winning_summary, now)
    quiet_report = ExperimentReport.from_summary(quiet_experiment, quiet_summary, now)

    reports = [winning_report, quiet_report]

    scale =
      reports
      |> Enum.map(& &1.best)
      |> Enum.reject(&is_nil/1)
      |> ExperimentReport.lift_scale()
      |> Kernel.||(1.0)

    html =
      render_component(&ExAbby.Live.ExperimentIndexLive.render/1, %{
        filter: :active,
        query: "",
        reports: reports,
        archived: [],
        counts: %{running: 2, significant: 1, archived: 0},
        scale: scale
      })

    assert html =~ "home_buy_now_price_v1"
    assert html =~ "search_empty_state"
    assert html =~ "p "
    assert html =~ "Healthy"
    assert html =~ "21d"
    assert html =~ "17d"
  end
end
