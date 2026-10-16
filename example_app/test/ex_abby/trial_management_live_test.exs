defmodule ExampleApp.TrialManagementLiveTest do
  use ExampleApp.DataCase

  alias ExAbby.{Experiments, Trial}
  alias ExAbby.Live.TrialManagementLive

  setup do
    {:ok, experiment} =
      Experiments.upsert_experiment_and_update_weights("trial_permissions", "", [
        {"control", 1.0},
        {"treatment", 1.0}
      ])

    experiment = Repo.preload(experiment, :variations)
    control = Enum.find(experiment.variations, &(&1.name == "control"))
    treatment = Enum.find(experiment.variations, &(&1.name == "treatment"))

    trial =
      %Trial{}
      |> Trial.changeset(%{
        experiment_id: experiment.id,
        variation_id: control.id,
        session_id: "owner-session",
        user_id: 42
      })
      |> Repo.insert!()

    %{trial: trial, treatment: treatment}
  end

  defp socket(assigns) do
    Phoenix.Component.assign(
      %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flash: %{}}},
      %{
        live_action: nil,
        current_user: nil,
        ex_abby_session_id: "other-session"
      }
    )
    |> Phoenix.Component.assign(assigns)
  end

  defp change_variation(socket, trial, variation) do
    TrialManagementLive.handle_event(
      "update-variation",
      %{"trial_id" => to_string(trial.id), "variation_id" => to_string(variation.id)},
      socket
    )
  end

  test "the event refuses foreign trials and permits the owning session or user", context do
    %{trial: trial, treatment: treatment} = context
    assert {:noreply, denied} = change_variation(socket(%{}), trial, treatment)
    assert denied.assigns.flash["error"] == "Failed to update variation"
    assert Repo.get!(Trial, trial.id).variation_id == trial.variation_id

    for assigns <- [%{ex_abby_session_id: "owner-session"}, %{current_user: %{id: 42}}] do
      Repo.update_all(from(t in Trial, where: t.id == ^trial.id),
        set: [variation_id: trial.variation_id]
      )

      assert {:noreply, allowed} = change_variation(socket(assigns), trial, treatment)
      assert allowed.assigns.flash == %{}
      assert Repo.get!(Trial, trial.id).variation_id == treatment.id
    end
  end

  test "the admin event permits a foreign trial but rejects a different experiment", context do
    %{trial: trial, treatment: treatment} = context

    assert {:noreply, allowed} =
             change_variation(socket(%{live_action: :admin}), trial, treatment)

    assert allowed.assigns.flash == %{}
    assert Repo.get!(Trial, trial.id).variation_id == treatment.id

    {:ok, other} =
      Experiments.upsert_experiment_and_update_weights("other_experiment", "", [{"control", 1.0}])

    [variation] = Repo.preload(other, :variations).variations
    assert {:noreply, denied} = change_variation(socket(%{live_action: :admin}), trial, variation)
    assert denied.assigns.flash["error"] == "Failed to update variation"
    assert Repo.get!(Trial, trial.id).variation_id == treatment.id
  end

  test "user_id query parameters only select another user's trials on the admin mount" do
    for {assigns, expected} <- [
          {%{}, nil},
          {%{current_user: %{id: 7}}, 7},
          {%{live_action: :admin}, 42}
        ] do
      assert {:noreply, result} =
               TrialManagementLive.handle_params(%{"user_id" => "42"}, "", socket(assigns))

      assert result.assigns.user_id == expected
      assert length(result.assigns.user_experiments) == if(expected == 42, do: 1, else: 0)
    end

    assert {:noreply, result} =
             TrialManagementLive.handle_params(
               %{"user_id" => "invalid"},
               "",
               socket(%{live_action: :admin})
             )

    assert result.assigns.user_id == nil
    assert result.assigns.user_experiments == []
  end
end
