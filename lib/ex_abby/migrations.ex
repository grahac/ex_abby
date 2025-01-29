defmodule ExAbby.Migrations do
  @moduledoc """
  Provides migration code to create/drop the ex_abby A/B testing tables.
  Host apps can simply do:

      defmodule MyApp.Repo.Migrations.CreateExAbbyTables do
        use Ecto.Migration

        def up, do: ExAbby.create_tables()
        def down, do: ExAbby.drop_tables()
      end
  """

  use Ecto.Migration

  def create_tables do
    # exabby_experiments
    create table(:exabby_experiments) do
      add(:name, :string, null: false)
      add(:success1_label, :string)
      add(:success2_label, :string)
      add(:description, :string)
      add(:start_time, :string)
      add(:end_time, :string)
      timestamps()
    end

    create(unique_index(:exabby_experiments, [:name]))

    # exabby_variations
    create table(:exabby_variations) do
      add(:experiment_id, references(:exabby_experiments, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:weight, :float, null: false, default: 1.0)
      timestamps()
    end

    create(index(:exabby_variations, [:experiment_id]))

    # exabby_trials
    create table(:exabby_trials) do
      add(:experiment_id, references(:exabby_experiments, on_delete: :delete_all), null: false)
      add(:variation_id, references(:exabby_variations, on_delete: :delete_all), null: false)
      add(:user_id, :integer)
      add(:session_id, :string)

      add(:success1_amount, :float, default: 0.0)
      add(:success1_count, :integer, default: 0)
      add(:success1_date, :utc_datetime, null: true)

      add(:success2_amount, :float, default: 0.0)
      add(:success2_count, :integer, default: 0)
      add(:success2_date, :utc_datetime, null: true)

      timestamps()
    end

    create table(:exabby_variations_audit_log) do
      add(:variation_id, references(:exabby_variations, on_delete: :delete_all), null: false)
      add(:previous_weight, :float, null: false)
      add(:new_weight, :float, null: false)
      add(:changed_by, :string)

      timestamps()
    end

    create(index(:exabby_variations_audit_log, [:variation_id]))

    create(index(:exabby_trials, [:experiment_id]))
    create(index(:exabby_trials, [:variation_id]))
    create(index(:exabby_trials, [:user_id]))
    create(index(:exabby_trials, [:session_id]))
  end

  def drop_tables do
    drop_if_exists(table(:exabby_trials))
    drop_if_exists(table(:exabby_variations_audit_log))
    drop_if_exists(table(:exabby_variations))
    drop_if_exists(table(:exabby_experiments))
  end

  # one time
  def add_start_end_experiment_fields do
    alter table(:exabby_experiments) do
      add(:start_time, :string)
      add(:end_time, :string)
    end
  end
end
