defmodule ExampleApp.ExAbbyTrialUniquenessTest do
  @moduledoc """
  DB-backed tests for the trial uniqueness fix that lives in the ex_abby library.

  The ex_abby library has no Repo of its own, so these run against example_app's
  Postgres test DB. The uniqueness partial indexes are applied by the
  20250620120000_ex_abby_trial_uniqueness migration before these tests run.
  """
  use ExampleApp.DataCase

  alias ExAbby.{Experiments, Trial, Variation}
  alias ExampleApp.Repo

  defp setup_experiment(name) do
    {:ok, _experiment} =
      Experiments.upsert_experiment_and_update_weights(name, "desc", [{"a", 1.0}, {"b", 1.0}])

    Experiments.get_experiment_by_name(name)
  end

  defp a_variation(experiment_id) do
    Repo.one(from(v in Variation, where: v.experiment_id == ^experiment_id, limit: 1))
  end

  defp session_trial_count(experiment_id, session_id) do
    Repo.aggregate(
      from(t in Trial, where: t.experiment_id == ^experiment_id and t.session_id == ^session_id),
      :count,
      :id
    )
  end

  defp user_trial_count(experiment_id, user_id) do
    Repo.aggregate(
      from(t in Trial, where: t.experiment_id == ^experiment_id and t.user_id == ^user_id),
      :count,
      :id
    )
  end

  describe "get_or_create_session_trial/2 idempotency" do
    test "repeated calls return the same variation and create exactly one row" do
      exp = setup_experiment("session_idem")

      assert {var1, :created} = Experiments.get_or_create_session_trial("session_idem", "sess-1")
      assert {var2, :existing} = Experiments.get_or_create_session_trial("session_idem", "sess-1")

      assert var1.id == var2.id
      assert session_trial_count(exp.id, "sess-1") == 1
    end

    test "concurrent calls for the same session create exactly one row and agree on variation" do
      exp = setup_experiment("session_conc")

      results =
        1..5
        |> Enum.map(fn _ ->
          Task.async(fn ->
            Experiments.get_or_create_session_trial("session_conc", "sess-c")
          end)
        end)
        |> Task.await_many()

      variation_ids = results |> Enum.map(fn {v, _status} -> v.id end) |> Enum.uniq()

      assert length(variation_ids) == 1
      assert session_trial_count(exp.id, "sess-c") == 1
    end
  end

  describe "get_or_create_user_trial/2 idempotency" do
    test "repeated calls return the same variation and create exactly one row" do
      exp = setup_experiment("user_idem")

      assert {var1, :created} = Experiments.get_or_create_user_trial("user_idem", 42)
      assert {var2, :existing} = Experiments.get_or_create_user_trial("user_idem", 42)

      assert var1.id == var2.id
      assert user_trial_count(exp.id, 42) == 1
    end

    test "concurrent calls for the same user create exactly one row and agree on variation" do
      exp = setup_experiment("user_conc")

      results =
        1..5
        |> Enum.map(fn _ ->
          Task.async(fn -> Experiments.get_or_create_user_trial("user_conc", 99) end)
        end)
        |> Task.await_many()

      variation_ids = results |> Enum.map(fn {v, _status} -> v.id end) |> Enum.uniq()

      assert length(variation_ids) == 1
      assert user_trial_count(exp.id, 99) == 1
    end
  end

  describe "DB-level uniqueness" do
    test "duplicate session trial insert returns a changeset error instead of raising" do
      exp = setup_experiment("session_reject")
      variation = a_variation(exp.id)

      attrs = %{experiment_id: exp.id, variation_id: variation.id, session_id: "dup"}

      assert {:ok, _} = %Trial{} |> Trial.changeset(attrs) |> Repo.insert()
      assert {:error, changeset} = %Trial{} |> Trial.changeset(attrs) |> Repo.insert()
      refute changeset.valid?

      assert Enum.any?(changeset.errors, fn {_field, {_msg, opts}} ->
               opts[:constraint] == :unique
             end)
    end
  end

  describe "deduplicate_trials SQL" do
    test "merges success counts onto the lowest-id row and leaves one row per group" do
      exp = setup_experiment("dedup")
      variation = a_variation(exp.id)

      # Drop the unique indexes (within the test transaction) so we can seed the
      # duplicate rows that older host DBs may already contain. Ecto.Migrator can't
      # be used here — it deadlocks against the single shared sandbox connection — so
      # we exercise the exact SQL that ExAbby.Migrations.deduplicate_trials/0 ships.
      Repo.query!("DROP INDEX ex_abby_trials_experiment_session_id_unique_index")
      Repo.query!("DROP INDEX ex_abby_trials_experiment_user_id_unique_index")

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, keep} =
        %Trial{}
        |> Trial.changeset(%{
          experiment_id: exp.id,
          variation_id: variation.id,
          session_id: "dupe",
          success1_count: 2,
          success1_amount: 5.0,
          success1_date: now,
          success2_count: 1,
          success2_amount: 4.0,
          success2_date: now
        })
        |> Repo.insert()

      {:ok, _drop} =
        %Trial{}
        |> Trial.changeset(%{
          experiment_id: exp.id,
          variation_id: variation.id,
          session_id: "dupe",
          success1_count: 3,
          success1_amount: 7.0,
          success1_date: DateTime.add(now, 3600, :second),
          success2_count: 6,
          success2_amount: 8.0,
          success2_date: DateTime.add(now, 3600, :second)
        })
        |> Repo.insert()

      assert session_trial_count(exp.id, "dupe") == 2

      Repo.query!(ExAbby.Migrations.merge_sql("session_id"))
      Repo.query!(ExAbby.Migrations.delete_sql("session_id"))

      assert session_trial_count(exp.id, "dupe") == 1

      survivor = Repo.get(Trial, keep.id)
      assert survivor.success1_count == 5
      assert survivor.success1_amount == 12.0
      assert survivor.success1_date == now
      assert survivor.success2_count == 7
      assert survivor.success2_amount == 12.0
      assert survivor.success2_date == now
    end

    test "user_id pass merges counts onto the lowest-id row and leaves one row per group" do
      exp = setup_experiment("dedup_user")
      variation = a_variation(exp.id)

      Repo.query!("DROP INDEX ex_abby_trials_experiment_session_id_unique_index")
      Repo.query!("DROP INDEX ex_abby_trials_experiment_user_id_unique_index")

      {:ok, keep} =
        %Trial{}
        |> Trial.changeset(%{
          experiment_id: exp.id,
          variation_id: variation.id,
          user_id: 7,
          success1_count: 2,
          success1_amount: 5.0
        })
        |> Repo.insert()

      {:ok, _drop} =
        %Trial{}
        |> Trial.changeset(%{
          experiment_id: exp.id,
          variation_id: variation.id,
          user_id: 7,
          success1_count: 3,
          success1_amount: 7.0
        })
        |> Repo.insert()

      assert user_trial_count(exp.id, 7) == 2

      Repo.query!(ExAbby.Migrations.merge_sql("user_id"))
      Repo.query!(ExAbby.Migrations.delete_sql("user_id"))

      assert user_trial_count(exp.id, 7) == 1

      survivor = Repo.get(Trial, keep.id)
      assert survivor.success1_count == 5
      assert survivor.success1_amount == 12.0
    end
  end

  describe "link_session_to_user/3 with the user uniqueness index" do
    test "linking a session to a user who already has a trial returns the existing trial, not a crash" do
      exp = setup_experiment("link_collision")

      # User already has a user-scoped trial for this experiment.
      {existing_var, :created} = Experiments.get_or_create_user_trial("link_collision", 7)
      # And an anonymous session trial exists for the same experiment.
      {_session_var, :created} =
        Experiments.get_or_create_session_trial("link_collision", "sess-x")

      assert {:ok, results} = Experiments.link_session_to_user("sess-x", 7, ["link_collision"])
      assert {:ok, linked_trial} = results["link_collision"]

      # No duplicate user trial was created, and the user's existing variation is preserved.
      assert user_trial_count(exp.id, 7) == 1
      assert linked_trial.variation_id == existing_var.id
    end
  end

  describe "resolve_created_or_raced/4 (race-recovery branch)" do
    @session_index :ex_abby_trials_experiment_session_id_unique_index

    setup do
      exp = setup_experiment("resolve")
      %{exp: exp, variation: a_variation(exp.id)}
    end

    test "returns {variation, :created} on a successful insert", %{variation: variation} do
      assert {^variation, :created} =
               Experiments.resolve_created_or_raced(
                 {:ok, %Trial{}},
                 variation,
                 @session_index,
                 fn -> flunk("refetch should not run on success") end
               )
    end

    test "on a unique violation, re-reads the winner and returns {_, :existing}", ctx do
      attrs = %{experiment_id: ctx.exp.id, variation_id: ctx.variation.id, session_id: "race"}
      {:ok, winner} = %Trial{} |> Trial.changeset(attrs) |> Repo.insert()
      {:error, changeset} = %Trial{} |> Trial.changeset(attrs) |> Repo.insert()

      assert {got, :existing} =
               Experiments.resolve_created_or_raced(
                 {:error, changeset},
                 ctx.variation,
                 @session_index,
                 fn -> winner end
               )

      assert got.id == ctx.variation.id
    end

    test "raises when the winner row vanished after the violation", ctx do
      attrs = %{experiment_id: ctx.exp.id, variation_id: ctx.variation.id, session_id: "vanish"}
      {:ok, _} = %Trial{} |> Trial.changeset(attrs) |> Repo.insert()
      {:error, changeset} = %Trial{} |> Trial.changeset(attrs) |> Repo.insert()

      assert_raise RuntimeError, ~r/vanished after a unique violation/, fn ->
        Experiments.resolve_created_or_raced(
          {:error, changeset},
          ctx.variation,
          @session_index,
          fn -> nil end
        )
      end
    end

    test "raises on an unexpected (non-unique) changeset error", %{variation: variation} do
      non_unique = Trial.changeset(%Trial{}, %{success1_count: -1})

      assert_raise RuntimeError, ~r/unexpected error creating trial/, fn ->
        Experiments.resolve_created_or_raced(
          {:error, non_unique},
          variation,
          @session_index,
          fn -> flunk("refetch should not run for a non-unique error") end
        )
      end
    end
  end
end
