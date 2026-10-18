defmodule ExAbby.ExperimentReportAlphaTest do
  # Changes application config, so it must not run alongside async tests.
  use ExUnit.Case, async: false

  alias ExAbby.{Experiment, ExperimentReport, Variation}

  setup do
    previous = Application.fetch_env(:ex_abby, :alpha)

    on_exit(fn ->
      case previous do
        {:ok, alpha} -> Application.put_env(:ex_abby, :alpha, alpha)
        :error -> Application.delete_env(:ex_abby, :alpha)
      end
    end)
  end

  test "the configured alpha decides significance and sets the interval level" do
    summary = [row(1, "control", 1000, 100), row(2, "bold", 1000, 173)]

    default = report(summary)
    assert default.alpha == 0.05
    assert default.best.p_value > 0.05 and default.best.p_value < 0.10
    refute default.best.significant?
    assert default.winners.success1 == nil

    Application.put_env(:ex_abby, :alpha, 0.10)

    relaxed = report(summary)
    assert relaxed.alpha == 0.10
    assert relaxed.best.significant?
    assert relaxed.winners.success1 == "bold"
    assert_in_delta relaxed.best.confidence_interval.confidence_level, 0.90, 1.0e-12
  end

  defp report(summary) do
    experiment = %Experiment{
      id: 1,
      name: "home_price",
      inserted_at: ~N[2026-08-11 00:00:00],
      variations: [
        %Variation{id: 1, name: "control", weight: 0.5},
        %Variation{id: 2, name: "bold", weight: 0.5}
      ]
    }

    ExperimentReport.from_summary(experiment, summary, ~U[2026-09-01 12:00:00Z])
  end

  defp row(id, name, trials, unique1) do
    metric = fn unique ->
      %{count: unique, unique_count: unique, amount: 0.0, rate: 0.0, amount_per_trial: 0.0}
    end

    %{
      variation_id: id,
      variation_name: name,
      trials: trials,
      excluded_trials: 0,
      success1: metric.(unique1),
      success2: metric.(0)
    }
  end
end
