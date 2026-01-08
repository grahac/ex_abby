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
    # ex_abby_experiments
    create table(:ex_abby_experiments) do
      add(:name, :string, null: false)
      add(:success1_label, :string)
      add(:success2_label, :string)
      add(:description, :string)
      add(:start_time, :string)
      add(:end_time, :string)
      add(:archived_at, :utc_datetime)
      timestamps()
    end

    create(unique_index(:ex_abby_experiments, [:name]))

    # ex_abby_variations
    create table(:ex_abby_variations) do
      add(:experiment_id, references(:ex_abby_experiments, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:weight, :float, null: false, default: 1.0)
      timestamps()
    end

    create(index(:ex_abby_variations, [:experiment_id]))

    # Add winner_variation_id after variations table exists
    alter table(:ex_abby_experiments) do
      add(:winner_variation_id, references(:ex_abby_variations, on_delete: :nilify_all))
    end

    # ex_abby_trials
    create table(:ex_abby_trials) do
      add(:experiment_id, references(:ex_abby_experiments, on_delete: :delete_all), null: false)
      add(:variation_id, references(:ex_abby_variations, on_delete: :delete_all), null: false)
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

    create table(:ex_abby_variations_audit_log) do
      add(:variation_id, references(:ex_abby_variations, on_delete: :delete_all), null: false)
      add(:previous_weight, :float, null: false)
      add(:new_weight, :float, null: false)
      add(:changed_by, :string)

      timestamps()
    end

    create(index(:ex_abby_variations_audit_log, [:variation_id]))

    create(index(:ex_abby_trials, [:experiment_id]))
    create(index(:ex_abby_trials, [:variation_id]))
    create(index(:ex_abby_trials, [:user_id]))
    create(index(:ex_abby_trials, [:session_id]))
  end

  def drop_tables do
    drop_if_exists(table(:ex_abby_trials))
    drop_if_exists(table(:ex_abby_variations_audit_log))
    drop_if_exists(table(:ex_abby_variations))
    drop_if_exists(table(:ex_abby_experiments))
  end

  # one time
  def add_start_end_experiment_fields do
    alter table(:ex_abby_experiments) do
      add(:start_time, :string)
      add(:end_time, :string)
    end
  end

  @doc """
  Upgrade from v1 to v2 (adds archive fields if they don't exist).

  Usage in host app migration:

      defmodule MyApp.Repo.Migrations.ExAbbyV2 do
        use Ecto.Migration
        def up, do: ExAbby.Migrations.v1_to_v2()
        def down, do: ExAbby.Migrations.v2_to_v1()
      end
  """
  def v1_to_v2 do
    execute """
    ALTER TABLE ex_abby_experiments
    ADD COLUMN IF NOT EXISTS archived_at timestamp(0)
    """

    execute """
    ALTER TABLE ex_abby_experiments
    ADD COLUMN IF NOT EXISTS winner_variation_id bigint
    REFERENCES ex_abby_variations(id) ON DELETE SET NULL
    """
  end

  @doc """
  Downgrade from v2 to v1 (removes archive fields).
  """
  def v2_to_v1 do
    alter table(:ex_abby_experiments) do
      remove(:archived_at)
      remove(:winner_variation_id)
    end
  end
end
