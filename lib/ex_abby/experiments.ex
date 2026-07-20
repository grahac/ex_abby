defmodule ExAbby.Experiments do
  @moduledoc """
  The Experiments context.
  """

  import Ecto.Query
  alias Ecto.Changeset
  alias ExAbby.{Experiment, Trial, Variation}
  require Logger
  # ------------------------------------------------------------------
  # Public API
  # ------------------------------------------------------------------

  @doc """
  Gets a single experiment with its variations.
  Returns nil if the experiment does not exist.
  """
  def get_experiment_by_id(id) do
    repo().get(Experiment, id)
    |> repo().preload(:variations)
  end

  @doc """
  Lists experiments with their variations preloaded.

  ## Options
    * `:status` - Filter by status: `:active`, `:archived`, or `:all` (default: `:all`)

  ## Examples
      list_experiments()                      # All experiments
      list_experiments(status: :active)       # Only active (non-archived)
      list_experiments(status: :archived)     # Only archived
  """
  def list_experiments(opts \\ []) do
    status = Keyword.get(opts, :status, :all)

    base_query =
      from(e in Experiment,
        order_by: [desc: e.inserted_at],
        preload: [:variations]
      )

    query =
      case status do
        :active -> from(e in base_query, where: is_nil(e.archived_at))
        :archived -> from(e in base_query, where: not is_nil(e.archived_at))
        :all -> base_query
      end

    repo().all(query)
  end

  @doc """
  Lists experiments that have trials for the given user_id.
  """
  def list_experiments_with_user_trials(user_id) when not is_nil(user_id) do
    query =
      from(e in Experiment,
        distinct: true,
        join: t in Trial,
        on: t.experiment_id == e.id,
        where: t.user_id == ^user_id,
        order_by: [desc: e.inserted_at],
        preload: [:variations]
      )

    repo().all(query)
  end

  @doc """
  Lists experiments that have trials for the given session_id.
  """
  def list_experiments_with_session_trials(session_id) when not is_nil(session_id) do
    query =
      from(e in Experiment,
        distinct: true,
        join: t in Trial,
        on: t.experiment_id == e.id,
        where: t.session_id == ^session_id,
        order_by: [desc: e.inserted_at],
        preload: [:variations]
      )

    repo().all(query)
  end

  @doc """
  Gets or creates an experiment by name.
  """
  def get_or_create_experiment(name) do
    get_experiment_by_name(name) || create_experiment(name)
  end

  @doc """
  Gets an experiment by name.
  """
  def get_experiment_by_name(name) do
    repo().one(from(e in Experiment, where: e.name == ^name))
  end

  @doc """
  Creates a new experiment with given name and optional description.
  """
  def create_experiment(name, description \\ nil) do
    %Experiment{}
    |> Experiment.changeset(%{name: name, description: description})
    |> repo().insert!()
  end

  @doc """
  Gets a variation by ID.
  """
  def get_variation(id), do: repo().get(Variation, id)

  @doc """
  Gets a variation by experiment_name and variation name.
  """
  def get_variation_by_name(experiment_name, var_name) do
    repo().one(
      from(v in Variation,
        join: e in Experiment,
        on: v.experiment_id == e.id,
        where: e.name == ^experiment_name and v.name == ^var_name
      )
    )
  end

  @doc """
  Creates or updates an experiment with variations.

  ## Options
    * `:update_weights` - Whether to update existing variation weights (default: true)
    * `:success1_label` - Label for success1 metric
    * `:success2_label` - Label for success2 metric
    * `:archived` - Set to true to archive the experiment (only updates if explicitly provided)
    * `:winner` - Winner variation name (string) - only used when archived: true
  """
  def upsert_experiment_and_update_weights(
        experiment_name,
        description,
        variations,
        opts \\ []
      )
      when is_list(variations) do
    update_weights = Keyword.get(opts, :update_weights, true)
    success1_label = Keyword.get(opts, :success1_label)
    success2_label = Keyword.get(opts, :success2_label)

    case get_experiment_by_name(experiment_name) do
      nil ->
        create_new_experiment_with_variations(experiment_name, description, variations, opts)

      experiment ->
        # Build base attributes
        base_attrs = %{
          description: description,
          success1_label: success1_label,
          success2_label: success2_label
        }

        # Only update archived fields if explicitly provided in opts
        attrs =
          if Keyword.has_key?(opts, :archived) do
            archived = Keyword.get(opts, :archived)
            winner_name = Keyword.get(opts, :winner)

            if archived do
              winner_variation_id = resolve_winner_variation_id(experiment, winner_name)

              Map.merge(base_attrs, %{
                archived_at: DateTime.utc_now() |> DateTime.truncate(:second),
                winner_variation_id: winner_variation_id
              })
            else
              Map.merge(base_attrs, %{
                archived_at: nil,
                winner_variation_id: nil
              })
            end
          else
            base_attrs
          end

        experiment
        |> Experiment.changeset(attrs)
        |> repo().update()

        if update_weights do
          Enum.each(variations, fn {var_name, weight} ->
            if variation = get_variation_by_name(experiment.id, var_name) do
              update_weight(variation, weight)
            end
          end)
        else
          # Just create any new variations without updating existing weights
          Enum.each(variations, fn {var_name, weight} ->
            unless get_variation_by_name(experiment.name, var_name) do
              create_variation(experiment, var_name, weight)
            end
          end)
        end

        {:ok, experiment}
    end
  end

  def update_weight(variation, weight, changed_by \\ "system") do
    if(weight != variation.weight) do
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:audit_log, %ExAbby.VariationAuditLog{
        variation_id: variation.id,
        previous_weight: variation.weight,
        new_weight: weight,
        changed_by: changed_by
      })
      |> Ecto.Multi.update(:variation, Changeset.change(variation, %{weight: weight}))
      |> repo().transaction()
    end
  end

  @doc """
  Gets or creates trials for multiple experiments for a session.
  Returns a list of {variation, status} tuples in the same order as the experiment names.
  """
  def get_or_create_session_trials(experiment_names, session_id) when is_list(experiment_names) do
    Enum.map(experiment_names, fn experiment_name ->
      get_or_create_session_trial(experiment_name, session_id)
    end)
  end

  @doc """
  Gets or creates a trial for a session.
  Returns {:error, :experiment_archived} if the experiment is archived.
  """
  def get_or_create_session_trial(experiment_name, session_id) do
    get_session_trial(experiment_name, session_id, restore_excluded?: false)
  end

  @doc false
  # Request-aware assignment calls this instead of issuing a no-op restore update
  # for every active trial. Direct persistence APIs keep their historical behavior.
  def get_or_restore_session_trial(experiment_name, session_id) do
    get_session_trial(experiment_name, session_id, restore_excluded?: true)
  end

  @doc """
  Gets a trial by session ID.
  """
  def get_trial_by_session(experiment_id, session_id) do
    repo().one(
      from(t in Trial,
        where: t.experiment_id == ^experiment_id and t.session_id == ^session_id
      )
    )
  end

  @doc """
  Gets all trials for a session ID across all experiments.
  """
  def get_all_trials_by_session(session_id) do
    repo().all(
      from(t in Trial,
        where: t.session_id == ^session_id,
        preload: [:experiment]
      )
    )
  end

  @doc """
  Marks active trials for the supplied session IDs as excluded.

  The update is transactional and idempotent: duplicate IDs are ignored, and
  already excluded rows are left unchanged. Returns `{:ok, count}`.
  """
  def exclude_session_trials(session_ids, opts \\ [])
      when is_list(session_ids) and is_list(opts) do
    reason = Keyword.get(opts, :reason, "bot")

    update_session_trials(session_ids, fn session_ids ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      repo().update_all(
        from(t in Trial,
          where: t.session_id in ^session_ids and is_nil(t.excluded_at)
        ),
        set: [excluded_at: now, exclusion_reason: reason]
      )
    end)
  end

  @doc """
  Clears exclusion audit fields for trials belonging to the supplied session IDs.

  The update is transactional and idempotent: duplicate IDs are ignored, and
  active rows are left unchanged. Returns `{:ok, count}`.
  """
  def restore_session_trials(session_ids) when is_list(session_ids) do
    update_session_trials(session_ids, fn session_ids ->
      repo().update_all(
        from(t in Trial,
          where: t.session_id in ^session_ids and not is_nil(t.excluded_at)
        ),
        set: [excluded_at: nil, exclusion_reason: nil]
      )
    end)
  end

  @doc false
  # Request-aware assignment code restores one experiment/session pair at a time so a
  # returning eligible human does not reactivate unrelated excluded experiments.
  def restore_excluded_session_trial(experiment_id, session_id) do
    {count, _} =
      repo().update_all(
        from(t in Trial,
          where:
            t.experiment_id == ^experiment_id and t.session_id == ^session_id and
              not is_nil(t.excluded_at)
        ),
        set: [excluded_at: nil, exclusion_reason: nil]
      )

    count
  end

  defp get_session_trial(experiment_name, session_id, opts) do
    experiment = get_experiment_by_name(experiment_name)
    restore_excluded? = Keyword.fetch!(opts, :restore_excluded?)

    case experiment do
      nil ->
        Logger.warning("Experiment not found #{experiment_name}")
        {:error, :experiment_not_found}

      %{archived_at: archived_at} when not is_nil(archived_at) ->
        {:error, :experiment_archived}

      experiment ->
        case get_trial_by_session(experiment.id, session_id) do
          nil ->
            variation = pick_weighted_variation(experiment.id)

            resolve_created_or_raced(
              create_trial(experiment.id, variation.id, session_id, nil),
              variation,
              :ex_abby_trials_experiment_session_id_unique_index,
              fn -> get_trial_by_session(experiment.id, session_id) end
            )

          %Trial{excluded_at: excluded_at} = trial
          when restore_excluded? and not is_nil(excluded_at) ->
            restore_excluded_session_trial(experiment.id, session_id)
            {get_variation(trial.variation_id), :restored}

          trial ->
            {get_variation(trial.variation_id), :existing}
        end
    end
  end

  def get_or_create_user_trials(experiment_names, user_id) when is_list(experiment_names) do
    Enum.map(experiment_names, fn experiment_name ->
      get_or_create_user_trial(experiment_name, user_id)
    end)
  end

  @doc """
  Gets or creates a trial for a user.
  Returns {:error, :experiment_archived} if the experiment is archived.
  """
  def get_or_create_user_trial(experiment_name, user_id) do
    experiment = get_experiment_by_name(experiment_name)

    case experiment do
      nil ->
        Logger.warning("Experiment not found #{experiment_name}")
        {:error, :experiment_not_found}

      %{archived_at: archived_at} when not is_nil(archived_at) ->
        {:error, :experiment_archived}

      experiment ->
        case get_trial_by_user(experiment.id, user_id) do
          nil ->
            variation = pick_weighted_variation(experiment.id)

            resolve_created_or_raced(
              create_trial(experiment.id, variation.id, nil, user_id),
              variation,
              :ex_abby_trials_experiment_user_id_unique_index,
              fn -> get_trial_by_user(experiment.id, user_id) end
            )

          trial ->
            {get_variation(trial.variation_id), :existing}
        end
    end
  end

  @doc """
  Records a success for a trial.
  """

  def record_success_for_user(experiment_name, user_id, opts \\ []) do
    with experiment when not is_nil(experiment) <- get_experiment_by_name(experiment_name),
         trial when not is_nil(trial) <- get_trial_by_user(experiment.id, user_id) do
      record_success(trial, opts)
    else
      nil ->
        Logger.warning(
          "Failed to record success: No existing trial found for user #{user_id} in experiment '#{experiment_name}'"
        )

        {:error, :no_trial_found}
    end
  end

  def record_success_for_session(experiment_name, session_id, opts \\ []) do
    with experiment when not is_nil(experiment) <- get_experiment_by_name(experiment_name),
         trial when not is_nil(trial) <- get_trial_by_session(experiment.id, session_id) do
      record_success(trial, opts)
    else
      nil ->
        Logger.warning(
          "Failed to record success: No existing trial found for session #{session_id} in experiment '#{experiment_name}'"
        )

        {:error, :no_trial_found}
    end
  end

  @success_types [:success1, :success2]

  @doc """
  Records a success for a trial.

  ## Options
    * `:amount` - Optional numeric value to track with the success (default: 0.0)
    * `:success_type` - Type of success to record, either `:success1` or `:success2` (default: `:success1`)
  """
  def record_success(trial, opts \\ [])

  def record_success(%Trial{excluded_at: excluded_at}, _opts) when not is_nil(excluded_at) do
    {:error, :trial_excluded}
  end

  def record_success(%Trial{} = trial, opts) when is_list(opts) do
    amount =
      case Keyword.get(opts, :amount, 0.0) do
        amount when is_binary(amount) ->
          case Float.parse(amount) do
            {num, _} -> num
            :error -> 0.0
          end

        amount ->
          amount || 0.0
      end

    success_type = Keyword.get(opts, :success_type, :success1)

    if success_type not in @success_types do
      raise ArgumentError,
            "success_type must be one of #{inspect(@success_types)}, got: #{inspect(success_type)}"
    end

    record_active_success(trial.id, success_type, amount)
  end

  @doc """
  Links a session-based trial to a user by updating the trial's user_id.
  This allows tracking the same experiment across both session and user contexts.

  Can be called with a list of experiment names or :all to link all session experiments.

  Returns {:ok, results} on success, {:error, details} on partial/full failure.
  """
  def link_session_to_user(session_id, user_id, :all) do
    trials = get_all_trials_by_session(session_id)
    experiment_names = Enum.map(trials, fn trial -> trial.experiment.name end)
    link_session_to_user(session_id, user_id, experiment_names)
  end

  def link_session_to_user(session_id, user_id, experiment_names)
      when is_list(experiment_names) do
    results =
      Enum.map(experiment_names, fn experiment_name ->
        case link_single_session_to_user(session_id, user_id, experiment_name) do
          {:ok, trial} -> {experiment_name, {:ok, trial}}
          {:error, reason} -> {experiment_name, {:error, reason}}
        end
      end)

    successful = for {name, {:ok, _trial}} <- results, do: name
    failed = for {name, {:error, _reason}} <- results, do: name

    if Enum.empty?(failed) do
      {:ok, Map.new(results)}
    else
      {:error, %{successful: successful, failed: failed}}
    end
  end

  defp link_single_session_to_user(session_id, user_id, experiment_name) do
    case get_experiment_by_name(experiment_name) do
      nil ->
        Logger.warning(
          "Failed to link session to user: No trial found for session #{session_id} in experiment '#{experiment_name}'"
        )

        {:error, :no_trial_found}

      experiment ->
        case repo().transaction(fn ->
               link_locked_session_trial(experiment, session_id, user_id)
             end) do
          {:ok, result} ->
            result

          {:error, :user_trial_exists} ->
            {:ok, get_trial_by_user(experiment.id, user_id)}

          {:error, {:update_failed, changeset}} ->
            {:error, changeset}
        end
    end
  end

  defp link_locked_session_trial(experiment, session_id, user_id) do
    trial =
      repo().one(
        from(t in Trial,
          where: t.experiment_id == ^experiment.id and t.session_id == ^session_id,
          lock: "FOR UPDATE"
        )
      )

    case trial do
      nil ->
        {:error, :no_trial_found}

      %Trial{excluded_at: excluded_at} when not is_nil(excluded_at) ->
        {:error, :trial_excluded}

      %Trial{} = trial ->
        # Use Trial.changeset (not a bare Changeset.change) so the user-uniqueness index
        # surfaces as {:error, changeset} instead of raising Ecto.ConstraintError.
        case trial |> Trial.changeset(%{user_id: user_id}) |> repo().update() do
          {:ok, updated} ->
            {:ok, updated}

          {:error, changeset} ->
            # The user already has a trial for this experiment, so the session trial
            # cannot also claim that user_id. Roll back the savepoint before the
            # outer caller reads that existing trial; PostgreSQL marks the current
            # transaction aborted after a unique violation.
            if unique_violation?(changeset, :ex_abby_trials_experiment_user_id_unique_index) do
              repo().rollback(:user_trial_exists)
            else
              repo().rollback({:update_failed, changeset})
            end
        end
    end
  end

  @doc """
  Returns a summary of results for a given experiment:
  variations, total trials, and details for both success types including counts, amounts, and rates.

  Example output:
  [
    %{
      variation_id: 1,
      variation_name: "Variation A",
      trials: 100,
      success1: %{
        count: 20,
        amount: 150.5,
        rate: 0.20,
        amount_per_trial: 1.505
      },
      success2: %{
        count: 15,
        amount: 75.25,
        rate: 0.15,
        amount_per_trial: 0.7525
      }
    }, ...
  ]
  """
  def experiment_summary(experiment_name) do
    experiment = get_experiment_by_name(experiment_name)

    if experiment do
      start_datetime =
        case ExAbby.DatetimeParser.parse(experiment.start_time) do
          {:ok, datetime} -> datetime
          _ -> nil
        end

      end_datetime =
        case ExAbby.DatetimeParser.parse(experiment.end_time) do
          {:ok, datetime} -> datetime
          _ -> nil
        end

      variations =
        repo().all(
          from(v in Variation,
            where: v.experiment_id == ^experiment.id,
            select: v
          )
        )

      Enum.map(variations, fn v ->
        query =
          from(t in Trial,
            where: t.variation_id == ^v.id
          )

        # Add date range filters if present
        query =
          if start_datetime do
            from(t in query, where: t.inserted_at >= ^start_datetime)
          else
            query
          end

        query =
          if end_datetime do
            from(t in query, where: t.inserted_at <= ^end_datetime)
          else
            query
          end

        stats =
          repo().one(
            from(t in query,
              select: %{
                trial_count: filter(count(t.id), is_nil(t.excluded_at)),
                excluded_trial_count: filter(count(t.id), not is_nil(t.excluded_at)),
                success1_sum: coalesce(filter(sum(t.success1_count), is_nil(t.excluded_at)), 0),
                success1_amount:
                  coalesce(filter(sum(t.success1_amount), is_nil(t.excluded_at)), 0.0),
                success1_unique:
                  count(
                    fragment(
                      "DISTINCT CASE WHEN ? IS NULL AND ? > 0 THEN ? END",
                      t.excluded_at,
                      t.success1_count,
                      t.id
                    )
                  ),
                success2_sum: coalesce(filter(sum(t.success2_count), is_nil(t.excluded_at)), 0),
                success2_amount:
                  coalesce(filter(sum(t.success2_amount), is_nil(t.excluded_at)), 0.0),
                success2_unique:
                  count(
                    fragment(
                      "DISTINCT CASE WHEN ? IS NULL AND ? > 0 THEN ? END",
                      t.excluded_at,
                      t.success2_count,
                      t.id
                    )
                  )
              }
            )
          ) ||
            %{
              trial_count: 0,
              excluded_trial_count: 0,
              success1_sum: 0,
              success1_amount: 0.0,
              success1_unique: 0,
              success2_sum: 0,
              success2_amount: 0.0,
              success2_unique: 0
            }

        %{
          variation_id: v.id,
          variation_name: v.name,
          trials: stats.trial_count,
          excluded_trials: stats.excluded_trial_count,
          success1: %{
            count: stats.success1_sum,
            unique_count: stats.success1_unique,
            amount: stats.success1_amount,
            rate:
              if(stats.trial_count > 0, do: stats.success1_unique / stats.trial_count, else: 0.0),
            amount_per_trial:
              if(stats.trial_count > 0, do: stats.success1_amount / stats.trial_count, else: 0.0)
          },
          success2: %{
            count: stats.success2_sum,
            unique_count: stats.success2_unique,
            amount: stats.success2_amount,
            rate:
              if(stats.trial_count > 0, do: stats.success2_unique / stats.trial_count, else: 0.0),
            amount_per_trial:
              if(stats.trial_count > 0, do: stats.success2_amount / stats.trial_count, else: 0.0)
          }
        }
      end)
    else
      []
    end
  end

  @doc """
  Records successes for multiple experiments with consistent error handling.
  Returns either:
    * `{:ok, %{experiment_name => {:ok, trial}}}` if all successful
    * `{:error, %{successful: [...], failed: [...]}}` if any failed
  """
  def record_multiple_successes(experiment_names, record_fn) when is_list(experiment_names) do
    results =
      Enum.map(experiment_names, fn experiment_name ->
        {experiment_name, record_fn.(experiment_name)}
      end)

    format_experiment_results(results)
  end

  @doc """
  Records successes for session-based experiments.
  """
  def record_session_successes(session_id, experiment_names, opts \\ []) do
    if is_nil(session_id) do
      {:error, %{successful: [], failed: experiment_names}}
    else
      record_multiple_successes(experiment_names, fn experiment_name ->
        with experiment when not is_nil(experiment) <- get_experiment_by_name(experiment_name),
             trial when not is_nil(trial) <- get_trial_by_session(experiment.id, session_id) do
          record_success(trial, opts)
        else
          nil -> {:error, :not_found}
        end
      end)
    end
  end

  @doc """
  Records successes for user-based experiments.
  """
  def record_user_successes(user_id, experiment_names, opts \\ []) do
    if is_nil(user_id) do
      {:error, %{successful: [], failed: experiment_names}}
    else
      record_multiple_successes(experiment_names, fn experiment_name ->
        record_success_for_user(experiment_name, user_id, opts)
      end)
    end
  end

  @doc """
  Formats a list of experiment results into a consistent response tuple.
  Returns either:
    * `{:ok, %{experiment_name => result}}` if all successful
    * `{:error, %{successful: [...], failed: [...]}}` if any failed
  """
  def format_experiment_results(results) when is_list(results) do
    {successful, failed} =
      results
      |> Enum.split_with(fn {_name, result} -> match?({:ok, _}, result) end)

    case failed do
      [] ->
        {:ok, Map.new(results)}

      _failed_trials ->
        {:error,
         %{
           successful: Enum.map(successful, fn {name, _} -> name end),
           failed: Enum.map(failed, fn {name, _} -> name end)
         }}
    end
  end

  @doc """
  Calculate a naive p-value for the difference in conversion rates among variations.
  For multi-variate, we might do pairwise comparisons or a more advanced approach
  (ANOVA, etc.). Here is a simple demonstration using a 2-proportion z-test
  for a pair of variations.  For multiple variations, you could do them pairwise.
  """
  def p_value_for_two_variations(experiment_name, var_name_a, var_name_b) do
    experiment = get_experiment_by_name(experiment_name)

    if experiment do
      var_a = get_variation_by_name(experiment.name, var_name_a)
      var_b = get_variation_by_name(experiment.name, var_name_b)

      if var_a && var_b do
        {trials_a, success_a} = get_trial_stats(var_a.id)
        {trials_b, success_b} = get_trial_stats(var_b.id)
        # compute conversion rates
        p_a = if trials_a > 0, do: success_a / trials_a, else: 0.0
        p_b = if trials_b > 0, do: success_b / trials_b, else: 0.0

        # 2-proportion z-test
        n_a = trials_a
        n_b = trials_b
        p_pooled = (success_a + success_b) / max(n_a + n_b, 1)
        se = :math.sqrt(p_pooled * (1 - p_pooled) * (1 / max(n_a, 1) + 1 / max(n_b, 1)))

        z =
          if se == 0.0 do
            0.0
          else
            (p_a - p_b) / se
          end

        # Convert Z to p-value (2-sided). For production, you might want a stats library.
        p_value = two_sided_pvalue(z)
        {:ok, p_value}
      else
        {:error, :variation_not_found}
      end
    else
      {:error, :experiment_not_found}
    end
  end

  @doc """
  Allows updating variation weights for an experiment.
  Example:
      update_variation_weights("exp_homepage", [
        {"Variation A", 1.0},
        {"Variation B", 2.0}
      ])
  """
  def update_variation_weights(experiment_name, variation_weights) do
    experiment = get_experiment_by_name(experiment_name)

    if experiment do
      for {var_name, new_weight} <- variation_weights do
        variation = get_variation_by_name(experiment.id, var_name)

        if variation do
          variation
          |> Changeset.change(%{weight: new_weight})
          |> repo().update()
        end
      end

      :ok
    else
      {:error, :not_found}
    end
  end

  @doc """
  Updates an experiment with the given attributes.

  ## Examples

      iex> update_experiment(experiment, %{start_time: "2024-01-01", end_time: "2024-12-31"})
      {:ok, %Experiment{}}
  """
  def update_experiment(%Experiment{} = experiment, attrs) do
    experiment
    |> Experiment.changeset(attrs)
    |> repo().update()
  end

  @doc """
  Archives an experiment, optionally setting a winner variation.
  Archived experiments will not accept new trials.

  ## Arguments
    * `experiment_id` - The ID of the experiment to archive
    * `winner_variation` - Optional winner: variation ID (integer) or name (string)

  ## Examples
      archive_experiment(123)                    # Archive without winner
      archive_experiment(123, "variant_a")       # Archive with winner by name
      archive_experiment(123, 456)               # Archive with winner by ID
  """
  def archive_experiment(experiment_id, winner_variation \\ nil) do
    experiment = get_experiment_by_id(experiment_id)

    winner_variation_id = resolve_winner_variation_id(experiment, winner_variation)

    experiment
    |> Experiment.changeset(%{
      archived_at: DateTime.utc_now() |> DateTime.truncate(:second),
      winner_variation_id: winner_variation_id
    })
    |> repo().update()
  end

  @doc """
  Unarchives an experiment, clearing the winner variation.
  """
  def unarchive_experiment(experiment_id) do
    experiment = get_experiment_by_id(experiment_id)

    experiment
    |> Experiment.changeset(%{
      archived_at: nil,
      winner_variation_id: nil
    })
    |> repo().update()
  end

  defp resolve_winner_variation_id(_experiment, nil), do: nil
  defp resolve_winner_variation_id(_experiment, id) when is_integer(id), do: id

  defp resolve_winner_variation_id(experiment, name) when is_binary(name) do
    case get_variation_by_name(experiment.name, name) do
      nil -> nil
      variation -> variation.id
    end
  end

  @doc """
  Gets all trials for a user, grouped by experiment.
  """
  def get_user_trials(user_id) do
    repo().all(
      from(t in Trial,
        where: t.user_id == ^user_id,
        preload: [:experiment, :variation]
      )
    )
  end

  @doc """
  Gets all session trials for a user, grouped by experiment.
  """
  def get_session_trials(session_id) do
    repo().all(
      from(t in Trial,
        where: t.session_id == ^session_id,
        preload: [:experiment, :variation]
      )
    )
  end

  @doc """
  Sets a specific variation for a session trial.
  Returns {:ok, trial} if successful, {:error, reason} otherwise.
  """
  def set_session_trial_variation(session_id, experiment_name, variation_name) do
    with experiment when not is_nil(experiment) <- get_experiment_by_name(experiment_name),
         variation when not is_nil(variation) <-
           get_variation_by_name(experiment_name, variation_name),
         trial when not is_nil(trial) <- get_trial_by_session(experiment.id, session_id) do
      update_trial_variation(trial.id, variation.id)
    else
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Updates the variation for a specific trial.
  """
  def update_trial_variation(trial_id, variation_id) do
    case repo().update_all(
           from(t in Trial, where: t.id == ^trial_id and is_nil(t.excluded_at)),
           set: [variation_id: variation_id]
         ) do
      {1, _} ->
        {:ok, repo().get!(Trial, trial_id)}

      {0, _} ->
        update_trial_variation_after_missed_update(trial_id, variation_id)
    end
  end

  # An exclusion can win the guarded UPDATE and then be restored before the
  # follow-up read. Lock the row for one final, bounded attempt instead of
  # recursively retrying while another process changes its exclusion status.
  defp update_trial_variation_after_missed_update(trial_id, variation_id) do
    {:ok, result} =
      repo().transaction(fn ->
        case repo().one(from(t in Trial, where: t.id == ^trial_id, lock: "FOR UPDATE")) do
          %Trial{excluded_at: excluded_at} when not is_nil(excluded_at) ->
            {:error, :trial_excluded}

          %Trial{} ->
            case repo().update_all(
                   from(t in Trial, where: t.id == ^trial_id and is_nil(t.excluded_at)),
                   set: [variation_id: variation_id]
                 ) do
              {1, _} -> {:ok, repo().get!(Trial, trial_id)}
              {0, _} -> {:error, :trial_excluded}
            end

          nil ->
            nil
        end
      end)

    result
  end

  def get_trial_by_user(experiment_id, user_id) do
    repo().one(
      from(t in Trial,
        where: t.experiment_id == ^experiment_id and t.user_id == ^user_id
      )
    )
  end

  # ------------------------------------------------------------------
  # Private Functions
  # ------------------------------------------------------------------

  defp update_session_trials(session_ids, update_fun) do
    session_ids = session_ids |> Enum.filter(&is_binary/1) |> Enum.uniq()

    case session_ids do
      [] ->
        {:ok, 0}

      session_ids ->
        repo().transaction(fn ->
          {count, _} = update_fun.(session_ids)
          count
        end)
    end
  end

  defp record_active_success(trial_id, :success1, amount) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    update_active_success(
      trial_id,
      from(t in Trial,
        where: t.id == ^trial_id and is_nil(t.excluded_at),
        update: [
          inc: [success1_count: 1, success1_amount: ^amount],
          set: [success1_date: fragment("COALESCE(?, ?)", t.success1_date, ^now)]
        ]
      )
    )
  end

  defp record_active_success(trial_id, :success2, amount) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    update_active_success(
      trial_id,
      from(t in Trial,
        where: t.id == ^trial_id and is_nil(t.excluded_at),
        update: [
          inc: [success2_count: 1, success2_amount: ^amount],
          set: [success2_date: fragment("COALESCE(?, ?)", t.success2_date, ^now)]
        ]
      )
    )
  end

  defp update_active_success(trial_id, query) do
    case repo().update_all(query, []) do
      {1, _} -> {:ok, repo().get!(Trial, trial_id)}
      {0, _} -> {:error, :trial_excluded}
    end
  end

  defp create_new_experiment_with_variations(name, description, variations, opts) do
    # Build base attributes
    base_attrs = %{
      name: name,
      description: description,
      success1_label: Keyword.get(opts, :success1_label),
      success2_label: Keyword.get(opts, :success2_label)
    }

    # Add archived fields if explicitly provided
    attrs =
      if Keyword.get(opts, :archived) do
        Map.merge(base_attrs, %{
          archived_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
      else
        base_attrs
      end

    exp_changeset = Experiment.changeset(%Experiment{}, attrs)

    case repo().insert(exp_changeset) do
      {:ok, experiment} ->
        for {var_name, weight} <- variations do
          create_variation(experiment, var_name, weight)
        end

        # Set winner after variations are created (need variation ID)
        experiment =
          if Keyword.get(opts, :archived) && Keyword.has_key?(opts, :winner) do
            winner_name = Keyword.get(opts, :winner)
            winner_variation_id = resolve_winner_variation_id(experiment, winner_name)

            {:ok, updated_exp} =
              experiment
              |> Experiment.changeset(%{winner_variation_id: winner_variation_id})
              |> repo().update()

            updated_exp
          else
            experiment
          end

        {:ok, experiment}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp create_variation(experiment, var_name, weight) do
    %Variation{}
    |> Variation.changeset(%{
      experiment_id: experiment.id,
      name: var_name,
      weight: weight
    })
    |> repo().insert()
  end

  defp create_trial(experiment_id, variation_id, session_id, user_id) do
    %Trial{}
    |> Trial.changeset(%{
      experiment_id: experiment_id,
      variation_id: variation_id,
      session_id: session_id,
      user_id: user_id
    })
    |> repo().insert()
  end

  @doc false
  # Resolves a create_trial/4 result into the public {variation, status} shape. On a lost
  # get-or-create race (unique violation) it re-reads the winner's row via refetch_fun.
  # Public only so the recovery path can be tested deterministically.
  def resolve_created_or_raced(create_result, variation, index_name, refetch_fun) do
    case create_result do
      {:ok, _trial} ->
        {variation, :created}

      {:error, changeset} ->
        if unique_violation?(changeset, index_name) do
          case refetch_fun.() do
            nil ->
              raise "ex_abby: trial for #{index_name} vanished after a unique violation; cannot resolve variation"

            trial ->
              {get_variation(trial.variation_id), :existing}
          end
        else
          raise "ex_abby: unexpected error creating trial: #{inspect(changeset.errors)}"
        end
    end
  end

  # Returns true if the changeset carries a unique-constraint error for the given index name.
  defp unique_violation?(%Ecto.Changeset{errors: errors}, index_name) do
    Enum.any?(errors, fn
      {_field, {_msg, opts}} ->
        opts[:constraint] == :unique and opts[:constraint_name] == Atom.to_string(index_name)
    end)
  end

  defp pick_weighted_variation(experiment_id) do
    variations = repo().all(from(v in Variation, where: v.experiment_id == ^experiment_id))
    total_weight = Enum.reduce(variations, 0.0, fn v, acc -> acc + v.weight end)

    if total_weight <= 0,
      do: raise("No variations or zero total weight for experiment=#{experiment_id}")

    r = :rand.uniform() * total_weight
    select_variation(variations, r)
  end

  defp select_variation([v | rest], r) do
    if r <= v.weight, do: v, else: select_variation(rest, r - v.weight)
  end

  defp select_variation([], _r), do: nil

  defp get_trial_stats(variation_id) do
    repo().one(
      from(t in Trial,
        where: t.variation_id == ^variation_id and is_nil(t.excluded_at),
        select:
          {count(t.id),
           count(fragment("DISTINCT CASE WHEN ? > 0 THEN ? END", t.success1_count, t.id))}
      )
    ) || {0, 0}
  end

  # Two-sided p-value approximation from Z
  defp two_sided_pvalue(z) do
    # We can do a normal distribution approximation.
    # For better accuracy, consider using a stats library (e.g., :math.erfc).
    # This is a rough example:
    # p = 2 * (1 - phi(|z|))
    # phi is the CDF of standard normal distribution.
    z_abs = abs(z)
    # approximate normal cdf
    cdf = 0.5 * (1.0 + :math.erf(z_abs / :math.sqrt(2)))
    2.0 * (1.0 - cdf)
  end

  defp repo() do
    case Application.get_env(:ex_abby, :repo) do
      nil ->
        raise "No Ecto repo configured for :ex_abby in your config! " <>
                "Please set config :ex_abby, repo: MyApp.Repo"

      repo_mod ->
        repo_mod
    end
  end
end
