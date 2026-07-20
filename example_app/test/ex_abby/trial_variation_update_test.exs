defmodule ExampleApp.ExAbbyTrialVariationUpdateTest do
  use ExampleApp.DataCase

  alias ExAbby.{Experiments, Trial, Variation}
  alias ExampleApp.Repo

  defp setup_experiment(name) do
    {:ok, _experiment} =
      Experiments.upsert_experiment_and_update_weights(name, "desc", [
        {"control", 1.0},
        {"treatment", 1.0}
      ])

    Experiments.get_experiment_by_name(name)
  end

  defp variation(experiment, name) do
    Repo.one!(
      from(v in Variation,
        where: v.experiment_id == ^experiment.id and v.name == ^name
      )
    )
  end

  defp insert_trial(experiment, variation, session_id) do
    %Trial{}
    |> Trial.changeset(%{
      experiment_id: experiment.id,
      variation_id: variation.id,
      session_id: session_id
    })
    |> Repo.insert!()
  end

  test "updates active trials while excluded and missing trials keep their result contracts" do
    experiment = setup_experiment("variation_update")
    control = variation(experiment, "control")
    treatment = variation(experiment, "treatment")
    active_trial = insert_trial(experiment, control, "active")
    excluded_trial = insert_trial(experiment, control, "excluded")

    assert {:ok, updated} = Experiments.update_trial_variation(active_trial.id, treatment.id)
    assert updated.variation_id == treatment.id

    assert {:ok, 1} = ExAbby.exclude_session_trials(["excluded"])

    assert {:error, :trial_excluded} =
             Experiments.update_trial_variation(excluded_trial.id, treatment.id)

    assert nil == Experiments.update_trial_variation(-1, treatment.id)
  end
end
