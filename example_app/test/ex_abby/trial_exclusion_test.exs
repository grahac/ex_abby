defmodule ExampleApp.ExAbbyTrialExclusionTest do
  use ExampleApp.DataCase

  import Plug.Conn
  import Plug.Test

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

  defp trial(id), do: Repo.get!(Trial, id)

  describe "trial exclusion schema" do
    test "exposes durable exclusion fields in the schema and database" do
      assert :excluded_at in Trial.__schema__(:fields)
      assert :exclusion_reason in Trial.__schema__(:fields)

      columns =
        Repo.query!("""
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = 'ex_abby_trials'
        """)
        |> Map.fetch!(:rows)
        |> Enum.map(&List.first/1)

      assert "excluded_at" in columns
      assert "exclusion_reason" in columns
    end
  end

  describe "session trial exclusion" do
    test "excludes and restores session trials idempotently without changing variations" do
      experiment = setup_experiment("excluded_restore")
      control = variation(experiment, "control")
      treatment = variation(experiment, "treatment")
      control_id = control.id
      treatment_id = treatment.id
      first = insert_trial(experiment, control, "session-a")
      second = insert_trial(experiment, treatment, "session-b")

      assert {:ok, 2} = ExAbby.exclude_session_trials(["session-a", "session-b", "session-a"])
      assert {:ok, 0} = ExAbby.exclude_session_trials(["session-a", "session-b"])

      assert %{excluded_at: %DateTime{}, exclusion_reason: "bot", variation_id: ^control_id} =
               trial(first.id)

      assert %{excluded_at: %DateTime{}, exclusion_reason: "bot", variation_id: ^treatment_id} =
               trial(second.id)

      assert {:ok, 2} = ExAbby.restore_session_trials(["session-a", "session-b"])
      assert {:ok, 0} = ExAbby.restore_session_trials(["session-a", "session-b"])

      assert %{excluded_at: nil, exclusion_reason: nil, variation_id: ^control_id} =
               trial(first.id)

      assert %{excluded_at: nil, exclusion_reason: nil, variation_id: ^treatment_id} =
               trial(second.id)
    end

    test "participates in the caller transaction without partial exclusions" do
      experiment = setup_experiment("excluded_rollback")
      control = variation(experiment, "control")
      first = insert_trial(experiment, control, "rollback-a")
      second = insert_trial(experiment, control, "rollback-b")

      assert {:error, :forced} =
               Repo.transaction(fn ->
                 assert {:ok, 2} =
                          ExAbby.exclude_session_trials(["rollback-a", "rollback-b"],
                            reason: "bot"
                          )

                 Repo.rollback(:forced)
               end)

      assert %{excluded_at: nil, exclusion_reason: nil} = trial(first.id)
      assert %{excluded_at: nil, exclusion_reason: nil} = trial(second.id)
    end
  end

  describe "excluded trial mutation guards" do
    test "successes, user linking, and manual variation changes reject excluded trials until restore" do
      experiment = setup_experiment("excluded_mutation_guards")
      control = variation(experiment, "control")
      treatment = variation(experiment, "treatment")
      control_id = control.id
      trial = insert_trial(experiment, control, "guarded-session")

      assert {:ok, 1} = ExAbby.exclude_session_trials(["guarded-session"])

      assert {:error, :trial_excluded} = Experiments.record_success(trial)

      assert {:error, %{successful: [], failed: ["excluded_mutation_guards"]}} =
               Experiments.record_session_successes("guarded-session", [
                 "excluded_mutation_guards"
               ])

      assert {:error, %{successful: [], failed: ["excluded_mutation_guards"]}} =
               Experiments.link_session_to_user("guarded-session", 42, [
                 "excluded_mutation_guards"
               ])

      assert {:error, :trial_excluded} =
               Experiments.update_trial_variation(trial.id, treatment.id)

      assert %{variation_id: ^control_id, user_id: nil, success1_count: 0} = trial(trial.id)

      assert {:ok, 1} = ExAbby.restore_session_trials(["guarded-session"])
      assert {:ok, updated} = Experiments.record_success(trial(trial.id))
      assert updated.success1_count == 1

      assert {:ok, linked} =
               Experiments.link_session_to_user("guarded-session", 42, [
                 "excluded_mutation_guards"
               ])

      assert {:ok, linked_trial} = linked["excluded_mutation_guards"]
      assert linked_trial.user_id == 42
      assert {:ok, changed} = Experiments.update_trial_variation(trial.id, treatment.id)
      assert changed.variation_id == treatment.id
    end
  end

  describe "reporting" do
    test "summaries and significance ignore excluded trials while retaining excluded totals" do
      experiment = setup_experiment("excluded_reporting")
      control = variation(experiment, "control")
      treatment = variation(experiment, "treatment")

      insert_trial(experiment, control, "active-control")

      excluded_control =
        %Trial{}
        |> Trial.changeset(%{
          experiment_id: experiment.id,
          variation_id: control.id,
          session_id: "excluded-control",
          success1_count: 1,
          success1_amount: 12.5,
          success2_count: 1,
          success2_amount: 8.0
        })
        |> Repo.insert!()

      insert_trial(experiment, treatment, "active-treatment")

      assert {:ok, 1} = ExAbby.exclude_session_trials(["excluded-control"])

      summary = Experiments.experiment_summary(experiment.name)
      control_summary = Enum.find(summary, &(&1.variation_id == control.id))
      treatment_summary = Enum.find(summary, &(&1.variation_id == treatment.id))

      assert control_summary.trials == 1
      assert control_summary.excluded_trials == 1
      assert control_summary.success1.count == 0
      assert control_summary.success1.rate == 0.0
      assert control_summary.success1.amount == 0.0
      assert control_summary.success2.count == 0
      assert control_summary.success2.unique_count == 0
      assert control_summary.success2.rate == 0.0
      assert control_summary.success2.amount == 0.0
      assert control_summary.success2.amount_per_trial == 0.0
      assert treatment_summary.trials == 1
      assert treatment_summary.excluded_trials == 0

      assert {:ok, 1.0} =
               Experiments.p_value_for_two_variations(experiment.name, "control", "treatment")

      assert %{excluded_at: %DateTime{}, success1_count: 1} = trial(excluded_control.id)
    end
  end

  describe "request eligibility" do
    test "controller and LiveView bots receive the fallback without creating trials" do
      experiment = setup_experiment("bot_fallback")

      conn =
        conn(:get, "/")
        |> init_test_session(%{"ex_abby_session_id" => "controller-bot"})
        |> assign(:ex_abby_bot, {:bot, :googlebot})

      {conn, variations} =
        ExAbby.PhoenixHelper.get_session_exp_variations(conn, [experiment.name])

      assert variations == %{experiment.name => "control"}
      assert conn.assigns.ex_abby_trials == %{experiment.name => "control"}

      assert Repo.aggregate(from(t in Trial, where: t.session_id == "controller-bot"), :count) ==
               0

      socket =
        ExAbby.LiveViewHelper.fetch_session_exp_variations_lv(
          %Phoenix.LiveView.Socket{},
          %{
            "ex_abby_session_id" => "liveview-bot",
            "ex_abby_bot" => {:bot, :gptbot}
          },
          [experiment.name]
        )

      assert socket.assigns.ex_abby_trials == %{experiment.name => "control"}
      assert Repo.aggregate(from(t in Trial, where: t.session_id == "liveview-bot"), :count) == 0
    end

    test "an eligible controller request restores only the requested excluded trial" do
      first_experiment = setup_experiment("restore_requested")
      second_experiment = setup_experiment("leave_unrequested")
      first_control = variation(first_experiment, "control")
      second_control = variation(second_experiment, "control")
      first_control_id = first_control.id
      second_control_id = second_control.id

      first_trial = insert_trial(first_experiment, first_control, "returning-human")
      second_trial = insert_trial(second_experiment, second_control, "returning-human")

      assert {:ok, 2} = ExAbby.exclude_session_trials(["returning-human"])

      conn =
        conn(:get, "/")
        |> init_test_session(%{"ex_abby_session_id" => "returning-human"})
        |> assign(:ex_abby_bot, :human)

      {_conn, variations} =
        ExAbby.PhoenixHelper.get_session_exp_variations(conn, [first_experiment.name])

      assert variations == %{first_experiment.name => "control"}
      assert %{excluded_at: nil, variation_id: ^first_control_id} = trial(first_trial.id)

      assert %{excluded_at: %DateTime{}, variation_id: ^second_control_id} =
               trial(second_trial.id)
    end

    test "bot mutation helpers leave existing trials unchanged" do
      experiment = setup_experiment("bot_mutation_guards")
      experiment_name = experiment.name
      control = variation(experiment, "control")
      treatment = variation(experiment, "treatment")
      original = insert_trial(experiment, control, "bot-mutation-session")

      conn =
        conn(:get, "/")
        |> init_test_session(%{"ex_abby_session_id" => "bot-mutation-session"})
        |> assign(:ex_abby_bot, {:bot, :googlebot})

      {_, {:error, :bot_excluded}} =
        ExAbby.PhoenixHelper.set_session_exp_variation(conn, experiment_name, treatment.name)

      assert {:error, :bot_excluded} =
               ExAbby.PhoenixHelper.record_success_for_session(conn, experiment_name)

      controller_linked =
        ExAbby.PhoenixHelper.link_session_to_user_conn(conn, %{id: 42}, [experiment_name])

      assert controller_linked.assigns.ex_abby_link_results == {:error, :bot_excluded}

      socket =
        ExAbby.LiveViewHelper.fetch_session_exp_variations_lv(
          %Phoenix.LiveView.Socket{},
          %{
            "ex_abby_session_id" => "bot-mutation-session",
            "ex_abby_bot" => {:bot, :gptbot}
          },
          [experiment_name]
        )

      assert {:error, :bot_excluded, _socket} =
               ExAbby.LiveViewHelper.set_session_exp_variation_lv(
                 socket,
                 experiment_name,
                 treatment.name
               )

      assert {:error, %{successful: [], failed: [^experiment_name]}} =
               ExAbby.LiveViewHelper.record_success_for_session_lv(socket, experiment_name)

      live_linked =
        ExAbby.LiveViewHelper.link_session_to_user_lv(socket, %{id: 42}, [experiment_name])

      assert live_linked.assigns.ex_abby_link_results == {:error, :bot_excluded}

      assert %{variation_id: variation_id, user_id: nil, success1_count: 0} = trial(original.id)
      assert variation_id == control.id
    end

    test "an eligible LiveView request restores only the requested excluded trial" do
      first_experiment = setup_experiment("live_restore_requested")
      second_experiment = setup_experiment("live_leave_unrequested")
      first_control = variation(first_experiment, "control")
      second_control = variation(second_experiment, "control")
      first_trial = insert_trial(first_experiment, first_control, "returning-live-human")
      second_trial = insert_trial(second_experiment, second_control, "returning-live-human")

      assert {:ok, 2} = ExAbby.exclude_session_trials(["returning-live-human"])

      socket =
        ExAbby.LiveViewHelper.fetch_session_exp_variations_lv(
          %Phoenix.LiveView.Socket{},
          %{
            "ex_abby_session_id" => "returning-live-human",
            "ex_abby_bot" => :human
          },
          [first_experiment.name]
        )

      assert socket.assigns.ex_abby_trials == %{first_experiment.name => "control"}
      assert %{excluded_at: nil, variation_id: variation_id} = trial(first_trial.id)
      assert variation_id == first_control.id
      assert %{excluded_at: %DateTime{}, variation_id: variation_id} = trial(second_trial.id)
      assert variation_id == second_control.id
    end

    test "LiveView bot fallbacks retain earlier assignments" do
      first_experiment = setup_experiment("live_bot_first")
      second_experiment = setup_experiment("live_bot_second")

      socket =
        ExAbby.LiveViewHelper.fetch_session_exp_variations_lv(
          %Phoenix.LiveView.Socket{},
          %{
            "ex_abby_session_id" => "live-bot-retention",
            "ex_abby_bot" => {:bot, :gptbot}
          },
          [first_experiment.name]
        )

      socket =
        ExAbby.LiveViewHelper.fetch_session_exp_variations_lv(
          socket,
          %{
            "ex_abby_session_id" => "live-bot-retention",
            "ex_abby_bot" => {:bot, :gptbot}
          },
          [second_experiment.name]
        )

      assert socket.assigns.ex_abby_trials == %{
               first_experiment.name => "control",
               second_experiment.name => "control"
             }
    end
  end
end
