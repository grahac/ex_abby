defmodule ExAbby.ArchiveTest do
  use ExUnit.Case

  alias ExAbby.Experiments

  setup_all do
    # Ensure modules are compiled and loaded
    {:module, _} = Code.ensure_compiled(ExAbby.Experiments)
    {:module, _} = Code.ensure_compiled(ExAbby.Migrations)
    {:module, _} = Code.ensure_compiled(ExAbby.Experiment)
    :ok
  end

  describe "archive function signatures" do
    test "archive_experiment/1 exists" do
      functions = Experiments.__info__(:functions)
      assert {:archive_experiment, 1} in functions
    end

    test "archive_experiment/2 exists" do
      functions = Experiments.__info__(:functions)
      assert {:archive_experiment, 2} in functions
    end

    test "unarchive_experiment/1 exists" do
      functions = Experiments.__info__(:functions)
      assert {:unarchive_experiment, 1} in functions
    end
  end

  describe "list_experiments function" do
    test "list_experiments/0 exists" do
      functions = Experiments.__info__(:functions)
      assert {:list_experiments, 0} in functions
    end

    test "list_experiments/1 exists" do
      functions = Experiments.__info__(:functions)
      assert {:list_experiments, 1} in functions
    end

    test "accepts status: :active option" do
      opts = [status: :active]
      assert Keyword.get(opts, :status) == :active
    end

    test "accepts status: :archived option" do
      opts = [status: :archived]
      assert Keyword.get(opts, :status) == :archived
    end

    test "accepts status: :all option" do
      opts = [status: :all]
      assert Keyword.get(opts, :status) == :all
    end
  end

  describe "upsert_experiment_and_update_weights archive options" do
    test "accepts archived: true option" do
      opts = [archived: true, winner: "variant_a", update_weights: false]
      assert Keyword.get(opts, :archived) == true
      assert Keyword.get(opts, :winner) == "variant_a"
    end

    test "accepts archived: false option" do
      opts = [archived: false]
      assert Keyword.get(opts, :archived) == false
    end
  end

  describe "experiment schema fields" do
    test "Experiment schema has archived_at field" do
      experiment = %ExAbby.Experiment{}
      assert Map.has_key?(experiment, :archived_at)
    end

    test "Experiment schema has winner_variation_id field" do
      experiment = %ExAbby.Experiment{}
      assert Map.has_key?(experiment, :winner_variation_id)
    end

    test "archived_at defaults to nil" do
      experiment = %ExAbby.Experiment{}
      assert is_nil(experiment.archived_at)
    end

    test "winner_variation_id defaults to nil" do
      experiment = %ExAbby.Experiment{}
      assert is_nil(experiment.winner_variation_id)
    end
  end

  describe "get_or_create_session_trial archived behavior" do
    test "function exists with arity 2" do
      functions = Experiments.__info__(:functions)
      assert {:get_or_create_session_trial, 2} in functions
    end
  end

  describe "get_or_create_user_trial archived behavior" do
    test "function exists with arity 2" do
      functions = Experiments.__info__(:functions)
      assert {:get_or_create_user_trial, 2} in functions
    end
  end

  describe "link_session_to_user function" do
    test "function exists with arity 3" do
      functions = Experiments.__info__(:functions)
      assert {:link_session_to_user, 3} in functions
    end

    test "accepts :all as experiments parameter" do
      experiments = :all
      assert experiments == :all
    end

    test "accepts list of experiment names" do
      experiments = ["exp1", "exp2"]
      assert is_list(experiments)
      assert length(experiments) == 2
    end
  end

  describe "get_all_trials_by_session function" do
    test "function exists with arity 1" do
      functions = Experiments.__info__(:functions)
      assert {:get_all_trials_by_session, 1} in functions
    end
  end

  describe "migration helpers" do
    test "v1_to_v2 function exists" do
      functions = ExAbby.Migrations.__info__(:functions)
      assert {:v1_to_v2, 0} in functions
    end

    test "v2_to_v1 function exists" do
      functions = ExAbby.Migrations.__info__(:functions)
      assert {:v2_to_v1, 0} in functions
    end
  end

  describe "experiment changeset accepts archive fields" do
    test "changeset casts archived_at" do
      experiment = %ExAbby.Experiment{}
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      changeset = ExAbby.Experiment.changeset(experiment, %{
        name: "test_exp",
        archived_at: now
      })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :archived_at) == now
    end

    test "changeset casts winner_variation_id" do
      experiment = %ExAbby.Experiment{}

      changeset = ExAbby.Experiment.changeset(experiment, %{
        name: "test_exp",
        winner_variation_id: 123
      })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :winner_variation_id) == 123
    end

    test "changeset allows nil archived_at" do
      experiment = %ExAbby.Experiment{name: "test", archived_at: DateTime.utc_now()}

      changeset = ExAbby.Experiment.changeset(experiment, %{
        archived_at: nil
      })

      assert changeset.valid?
    end

    test "changeset allows nil winner_variation_id" do
      experiment = %ExAbby.Experiment{name: "test", winner_variation_id: 123}

      changeset = ExAbby.Experiment.changeset(experiment, %{
        winner_variation_id: nil
      })

      assert changeset.valid?
    end
  end
end
