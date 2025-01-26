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
        update_weights \\ true
      )
      when is_list(variations) do
    case get_experiment_by_name(experiment_name) do
      nil ->
        create_new_experiment_with_variations(experiment_name, description, variations)

      experiment ->
        if update_weights do
          Enum.each(variations, fn {var_name, weight} ->
            if variation = get_variation_by_name(experiment.id, var_name) do
              variation
              |> Changeset.change(%{weight: weight})
              |> repo().update()
            end
          end)
        else
          # Just create any new variations without updating existing weights
          Enum.each(variations, fn {var_name, weight} ->
            unless get_variation_by_name(experiment.id, var_name) do
              create_variation(experiment, var_name, weight)
            end
          end)
        end

        {:ok, experiment}
    end
  end

  @doc """
  Gets or creates a trial for a session.
  """
  def get_or_create_session_trial(experiment_name, session_id) do
    experiment = get_experiment_by_name(experiment_name)

    case experiment do
      nil ->
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

  @doc """
  Gets or creates a trial for a user.
  """
  def get_or_create_user_trial(experiment_name, user_id) do
    experiment = get_experiment_by_name(experiment_name)

    case experiment do
      nil ->
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

  def record_success_for_user(experiment_name, user_id) do
    case get_or_create_user_trial(experiment_name, user_id) do
      {:error, :experiment_not_found} ->
        Logger.warning("Failed to record success: Experiment '#{experiment_name}' not found")
        {:error, :experiment_not_found}

      {_variation, _status} when is_nil(user_id) ->
        Logger.warning(
          "Failed to record success: user_id is nil for experiment '#{experiment_name}'"
        )

        {:error, :user_id_nil}

      {variation, status} ->
        record_success(variation)
        {:ok, {variation, status}}
    end
  end

  def record_success_for_session(experiment_name, session_id) do
    case get_or_create_session_trial(experiment_name, session_id) do
      {:error, :experiment_not_found} ->
        Logger.warning("Failed to record success: Experiment '#{experiment_name}' not found")
        {:error, :experiment_not_found}

      {_variation, _status} when is_nil(session_id) ->
        Logger.warning(
          "Failed to record success: session_id is nil for experiment '#{experiment_name}'"
        )

        {:error, :session_id_nil}

      {variation, status} ->
        record_success(variation)
        {:ok, {variation, status}}
    end
  end

  def record_success(trial) do
    updated_count = trial.success_count + 1

    changes =
      if trial.success_count == 0 do
        %{
          success_count: updated_count,
          success_date: DateTime.utc_now() |> DateTime.truncate(:second)
        }
      else
        %{success_count: updated_count}
      end

    {:ok, _trial} =
      trial
      |> Changeset.change(changes)
      |> repo().update()
  end

  @doc """
  Returns a summary of results for a given experiment:
  variations, total trials, successes, conversion rate, etc.

  Example output:
  [
    %{
      variation_id: 1,
      variation_name: "Variation A",
      trials: 100,
      successes: 20,
      conversion_rate: 0.20
    }, ...
  ]
  You could also compute p-values between variations here.
  """
  def experiment_summary(experiment_name) do
    experiment = get_experiment_by_name(experiment_name)

    if experiment do
      variations =
        repo().all(
          from(v in Variation,
            where: v.experiment_id == ^experiment.id,
            select: v
          )
        )

      # for each variation, count trials and sum success_count
      Enum.map(variations, fn v ->
        {trial_count, success_sum} =
          repo().one(
            from(t in Trial,
              where: t.variation_id == ^v.id,
              select: {count(t.id), sum(t.success_count)}
            )
          )

        trial_count = trial_count || 0
        success_sum = success_sum || 0

        %{
          variation_id: v.id,
          variation_name: v.name,
          trials: trial_count,
          successes: success_sum,
          conversion_rate:
            if trial_count > 0 do
              success_sum / trial_count
            else
              0.0
            end
        }
      end)
    else
      []
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

  # ------------------------------------------------------------------
  # Private Functions
  # ------------------------------------------------------------------

  defp get_trial_by_user(experiment_id, user_id) do
    repo().one(
      from(t in Trial,
        where: t.experiment_id == ^experiment_id and t.user_id == ^user_id
      )
    )
  end

  defp create_new_experiment_with_variations(name, description, variations) do
    exp_changeset =
      %Experiment{}
      |> Experiment.changeset(%{name: name, description: description})

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
