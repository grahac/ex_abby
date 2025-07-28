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
  Lists all experiments with their variations preloaded.
  """
  def list_experiments do
    repo().all(
      from(e in Experiment,
        order_by: [desc: e.inserted_at],
        preload: [:variations]
      )
    )
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
        # Update experiment attributes
        experiment
        |> Experiment.changeset(%{
          description: description,
          success1_label: success1_label,
          success2_label: success2_label
        })
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
  """
  def get_or_create_session_trial(experiment_name, session_id) do
    experiment = get_experiment_by_name(experiment_name)

    case experiment do
      nil ->
        Logger.warning("Experiment not found #{experiment_name}")
        {:error, :experiment_not_found}

      experiment ->
        case get_trial_by_session(experiment.id, session_id) do
          nil ->
            variation = pick_weighted_variation(experiment.id)
            create_trial(experiment.id, variation.id, session_id, nil)
            {variation, :created}

          trial ->
            {get_variation(trial.variation_id), :existing}
        end
    end
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

  def get_or_create_user_trials(experiment_names, user_id) when is_list(experiment_names) do
    Enum.map(experiment_names, fn experiment_name ->
      get_or_create_user_trial(experiment_name, user_id)
    end)
  end

  @doc """
  Gets or creates a trial for a user.
  """
  def get_or_create_user_trial(experiment_name, user_id) do
    experiment = get_experiment_by_name(experiment_name)

    case experiment do
      nil ->
        Logger.warning("Experiment not found #{experiment_name}")

        {:error, :experiment_not_found}

      experiment ->
        case get_trial_by_user(experiment.id, user_id) do
          nil ->
            variation = pick_weighted_variation(experiment.id)
            create_trial(experiment.id, variation.id, nil, user_id)
            {variation, :created}

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
      {:ok, trial}
    else
      nil ->
        Logger.warning("Failed to record success: No existing trial found for user #{user_id} in experiment '#{experiment_name}'")
        {:error, :no_trial_found}
    end
  end

  def record_success_for_session(experiment_name, session_id, opts \\ []) do
    with experiment when not is_nil(experiment) <- get_experiment_by_name(experiment_name),
         trial when not is_nil(trial) <- get_trial_by_session(experiment.id, session_id) do
      record_success(trial, opts)
      {:ok, trial}
    else
      nil ->
        Logger.warning("Failed to record success: No existing trial found for session #{session_id} in experiment '#{experiment_name}'")
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
  def record_success(trial, opts \\ []) when is_list(opts) do
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

    {count_field, date_field, amount_field} = get_success_fields(success_type)
    current_count = Map.get(trial, count_field, 0)
    current_amount = Map.get(trial, amount_field, 0.0)

    changes =
      if current_count == 0 do
        %{
          count_field => current_count + 1,
          date_field => DateTime.utc_now() |> DateTime.truncate(:second),
          amount_field => current_amount + amount
        }
      else
        %{
          count_field => current_count + 1,
          amount_field => current_amount + amount
        }
      end

    {:ok, _trial} =
      trial
      |> Changeset.change(changes)
      |> repo().update()
  end

  defp get_success_fields(:success1), do: {:success1_count, :success1_date, :success1_amount}
  defp get_success_fields(:success2), do: {:success2_count, :success2_date, :success2_amount}

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
                trial_count: count(t.id),
                success1_sum: coalesce(sum(t.success1_count), 0),
                success1_amount: coalesce(sum(t.success1_amount), 0.0),
                success1_unique:
                  count(fragment("DISTINCT CASE WHEN ? > 0 THEN ? END", t.success1_count, t.id)),
                success2_sum: coalesce(sum(t.success2_count), 0),
                success2_amount: coalesce(sum(t.success2_amount), 0.0),
                success2_unique:
                  count(fragment("DISTINCT CASE WHEN ? > 0 THEN ? END", t.success2_count, t.id))
              }
            )
          ) ||
            %{
              trial_count: 0,
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
          {:ok, trial}
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
      var_a = get_variation_by_name(experiment.id, var_name_a)
      var_b = get_variation_by_name(experiment.id, var_name_b)

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
    trial = repo().get(Trial, trial_id)

    if trial do
      trial
      |> Ecto.Changeset.change(%{variation_id: variation_id})
      |> repo().update()
    end
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

  defp create_new_experiment_with_variations(name, description, variations, opts) do
    exp_changeset =
      %Experiment{}
      |> Experiment.changeset(%{
        name: name,
        description: description,
        success1_label: Keyword.get(opts, :success1_label),
        success2_label: Keyword.get(opts, :success2_label)
      })

    case repo().insert(exp_changeset) do
      {:ok, experiment} ->
        for {var_name, weight} <- variations do
          create_variation(experiment, var_name, weight)
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
    |> repo().insert!()
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
        where: t.variation_id == ^variation_id,
        select: {count(t.id), sum(t.success_count)}
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
