defmodule ExampleApp.ExperimentSummaryTest do
  use ExampleApp.DataCase

  alias ExAbby.{Experiments, Trial, Variation}
  alias ExampleApp.Repo

  test "preserves grouped summary semantics for both supported inputs" do
    {:ok, experiment} =
      Experiments.upsert_experiment_and_update_weights(
        "grouped_summary_parity",
        "Grouped summary parity",
        [{"control", 1.0}, {"treatment", 1.0}]
      )

    {:ok, experiment} =
      Experiments.update_experiment(experiment, %{
        start_time: "01/02/2026 12:00 AM UTC",
        end_time: "01/03/2026 12:00 AM UTC"
      })

    control = variation(experiment, "control")
    treatment = variation(experiment, "treatment")

    insert_trial!(experiment, control, "before", ~N[2026-01-01 23:59:59],
      success1_count: 20,
      success1_amount: 200.0,
      success2_count: 20,
      success2_amount: 200.0
    )

    insert_trial!(experiment, control, "at-start", ~N[2026-01-02 00:00:00],
      success1_count: 2,
      success1_amount: 6.0
    )

    insert_trial!(experiment, control, "inside", ~N[2026-01-02 12:00:00],
      success2_count: 2,
      success2_amount: 10.0
    )

    insert_trial!(experiment, control, "at-end", ~N[2026-01-03 00:00:00],
      success1_count: 1,
      success1_amount: 4.0,
      success2_count: 1,
      success2_amount: 5.0
    )

    insert_trial!(experiment, control, "excluded", ~N[2026-01-02 18:00:00],
      excluded_at: ~U[2026-01-02 18:30:00Z],
      success1_count: 9,
      success1_amount: 99.0,
      success2_count: 9,
      success2_amount: 99.0
    )

    insert_trial!(experiment, control, "after", ~N[2026-01-03 00:00:01],
      success1_count: 20,
      success1_amount: 200.0,
      success2_count: 20,
      success2_amount: 200.0
    )

    insert_trial!(experiment, treatment, "treatment-before", ~N[2026-01-01 23:59:59])
    insert_trial!(experiment, treatment, "treatment-after", ~N[2026-01-03 00:00:01])

    by_name = Experiments.experiment_summary(experiment.name)
    by_struct = Experiments.experiment_summary(experiment)

    assert by_name == by_struct

    control_summary = Enum.find(by_name, &(&1.variation_id == control.id))
    treatment_summary = Enum.find(by_name, &(&1.variation_id == treatment.id))

    assert control_summary.trials == 3
    assert control_summary.excluded_trials == 1
    assert control_summary.success1.count == 3
    assert control_summary.success1.unique_count == 2
    assert control_summary.success1.amount == 10.0
    assert_in_delta control_summary.success1.rate, 2 / 3, 1.0e-12
    assert_in_delta control_summary.success1.amount_per_trial, 10 / 3, 1.0e-12
    assert control_summary.success2.count == 3
    assert control_summary.success2.unique_count == 2
    assert control_summary.success2.amount == 15.0
    assert_in_delta control_summary.success2.rate, 2 / 3, 1.0e-12
    assert control_summary.success2.amount_per_trial == 5.0

    assert treatment_summary.trials == 0
    assert treatment_summary.excluded_trials == 0

    assert treatment_summary.success1 == %{
             count: 0,
             unique_count: 0,
             amount: 0.0,
             rate: 0.0,
             amount_per_trial: 0.0
           }

    assert treatment_summary.success2 == %{
             count: 0,
             unique_count: 0,
             amount: 0.0,
             rate: 0.0,
             amount_per_trial: 0.0
           }
  end

  defp variation(experiment, name) do
    Repo.one!(
      from(v in Variation,
        where: v.experiment_id == ^experiment.id and v.name == ^name
      )
    )
  end

  defp insert_trial!(experiment, variation, session_id, inserted_at, attrs \\ []) do
    defaults = %{
      experiment_id: experiment.id,
      variation_id: variation.id,
      session_id: session_id,
      success1_count: 0,
      success1_amount: 0.0,
      success2_count: 0,
      success2_amount: 0.0,
      inserted_at: inserted_at,
      updated_at: inserted_at
    }

    defaults
    |> Map.merge(Map.new(attrs))
    |> then(&struct!(Trial, &1))
    |> Repo.insert!()
  end
end
