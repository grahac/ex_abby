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
    execute("""
    ALTER TABLE ex_abby_experiments
    ADD COLUMN IF NOT EXISTS archived_at timestamp(0)
    """)

    execute("""
    ALTER TABLE ex_abby_experiments
    ADD COLUMN IF NOT EXISTS winner_variation_id bigint
    REFERENCES ex_abby_variations(id) ON DELETE SET NULL
    """)
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

  @doc """
  Adds partial unique indexes preventing duplicate trials per experiment.

  A trial has either a `session_id` or a `user_id` (never both, unless linked), so the
  indexes are partial (`WHERE ... IS NOT NULL`) and keep both columns nullable.

  Host DBs that may already contain duplicate trials must run
  `deduplicate_trials/0` FIRST, or this migration will fail.

  ## Options

    * `:concurrently` - when `true`, builds the indexes with `CREATE INDEX CONCURRENTLY`
      so the build does not take an `ACCESS EXCLUSIVE` lock that blocks writes. Defaults
      to `false`. Required for large production tables.

  ## Simple usage (small tables / dev — runs inside one transaction)

      defmodule MyApp.Repo.Migrations.ExAbbyTrialUniqueness do
        use Ecto.Migration

        def up do
          ExAbby.Migrations.deduplicate_trials()
          ExAbby.Migrations.add_trial_uniqueness()
        end

        def down, do: ExAbby.Migrations.remove_trial_uniqueness()
      end

  ## Production usage (large tables) — split into TWO migrations

  `CREATE INDEX CONCURRENTLY` cannot run inside a transaction, so the dedup (which must
  stay transactional) and the concurrent index build must be separate migrations:

      # 1. _dedup migration (transactional — default)
      defmodule MyApp.Repo.Migrations.ExAbbyDedupTrials do
        use Ecto.Migration
        def up, do: ExAbby.Migrations.deduplicate_trials()
        def down, do: :ok
      end

      # 2. _uniqueness migration (concurrent — no transaction/lock)
      defmodule MyApp.Repo.Migrations.ExAbbyTrialUniqueness do
        use Ecto.Migration
        @disable_ddl_transaction true
        @disable_migration_lock true

        def up, do: ExAbby.Migrations.add_trial_uniqueness(concurrently: true)
        def down, do: ExAbby.Migrations.remove_trial_uniqueness(concurrently: true)
      end
  """
  def add_trial_uniqueness(opts \\ []) do
    concurrently = Keyword.get(opts, :concurrently, false)

    create(
      unique_index(:ex_abby_trials, [:experiment_id, :session_id],
        name: :ex_abby_trials_experiment_session_id_unique_index,
        where: "session_id IS NOT NULL",
        concurrently: concurrently
      )
    )

    create(
      unique_index(:ex_abby_trials, [:experiment_id, :user_id],
        name: :ex_abby_trials_experiment_user_id_unique_index,
        where: "user_id IS NOT NULL",
        concurrently: concurrently
      )
    )
  end

  @doc """
  Removes the partial unique indexes added by `add_trial_uniqueness/1`.

  Accepts the same `:concurrently` option so a concurrent build can be reversed with a
  concurrent drop (required when the migration sets `@disable_ddl_transaction true`).
  """
  def remove_trial_uniqueness(opts \\ []) do
    concurrently = Keyword.get(opts, :concurrently, false)

    drop(
      index(:ex_abby_trials, [:experiment_id, :session_id],
        name: :ex_abby_trials_experiment_session_id_unique_index,
        concurrently: concurrently
      )
    )

    drop(
      index(:ex_abby_trials, [:experiment_id, :user_id],
        name: :ex_abby_trials_experiment_user_id_unique_index,
        concurrently: concurrently
      )
    )
  end

  @doc """
  Merges duplicate trials so `add_trial_uniqueness/0` can run safely.

  For each `(experiment_id, session_id)` and `(experiment_id, user_id)` group, success
  counts/amounts are summed onto the lowest-id surviving row, the earliest non-null
  success dates are kept, and the higher-id duplicate rows are deleted. Run this BEFORE
  `add_trial_uniqueness/0` on any DB that may already hold duplicates.
  """
  def deduplicate_trials do
    execute(merge_sql("session_id"))
    execute(delete_sql("session_id"))
    execute(merge_sql("user_id"))
    execute(delete_sql("user_id"))
  end

  @doc false
  # Sums success counts/amounts (and keeps earliest success dates) from all duplicate
  # rows in a group onto the lowest-id surviving row. Public only so the ex_abby test
  # suite can exercise the exact SQL without an Ecto.Migrator run. The guard keeps the
  # raw interpolation safe — only literal trial key columns are ever accepted.
  def merge_sql(key_column) when key_column in ["session_id", "user_id"] do
    """
    WITH winners AS (
      SELECT MIN(id) AS keep_id, experiment_id, #{key_column} AS key
      FROM ex_abby_trials
      WHERE #{key_column} IS NOT NULL
      GROUP BY experiment_id, #{key_column}
      HAVING COUNT(*) > 1
    ),
    merged AS (
      SELECT
        w.keep_id,
        COALESCE(SUM(t.success1_amount), 0.0) AS success1_amount,
        COALESCE(SUM(t.success1_count), 0) AS success1_count,
        MIN(t.success1_date) AS success1_date,
        COALESCE(SUM(t.success2_amount), 0.0) AS success2_amount,
        COALESCE(SUM(t.success2_count), 0) AS success2_count,
        MIN(t.success2_date) AS success2_date
      FROM winners w
      JOIN ex_abby_trials t
        ON t.experiment_id = w.experiment_id AND t.#{key_column} = w.key
      GROUP BY w.keep_id
    )
    UPDATE ex_abby_trials t
    SET success1_amount = m.success1_amount,
        success1_count = m.success1_count,
        success1_date = m.success1_date,
        success2_amount = m.success2_amount,
        success2_count = m.success2_count,
        success2_date = m.success2_date
    FROM merged m
    WHERE t.id = m.keep_id
    """
  end

  @doc false
  # Deletes the higher-id duplicate rows, leaving only the lowest-id row per group.
  def delete_sql(key_column) when key_column in ["session_id", "user_id"] do
    """
    DELETE FROM ex_abby_trials t
    USING (
      SELECT MIN(id) AS keep_id, experiment_id, #{key_column} AS key
      FROM ex_abby_trials
      WHERE #{key_column} IS NOT NULL
      GROUP BY experiment_id, #{key_column}
      HAVING COUNT(*) > 1
    ) w
    WHERE t.experiment_id = w.experiment_id
      AND t.#{key_column} = w.key
      AND t.id <> w.keep_id
    """
  end
end
