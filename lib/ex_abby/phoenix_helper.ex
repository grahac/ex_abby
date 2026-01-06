defmodule ExAbby.PhoenixHelper do
  @moduledoc """
  Provides Phoenix-based A/B testing functions that operate with a Plug.Conn
  """

  alias ExAbby.Experiments
  @session_key "ex_abby_session_id"

  require Logger

  @doc """
  Retrieves or assigns variations for multiple session-based experiments.
  Returns {conn, variations_map} where variations_map is %{experiment_name => variation_name}.
  """
  def get_session_exp_variations(conn, experiment_names) when is_list(experiment_names) do
    # Get existing trials map or initialize empty map
    existing_trials = Map.get(conn.assigns, :ex_abby_trials, %{})

    # Get session ID or create new one
    session_id = Plug.Conn.get_session(conn, @session_key)

    {conn, session_id} =
      if is_nil(session_id) do
        new_id = generate_session_id()
        {Plug.Conn.put_session(conn, @session_key, new_id), new_id}
      else
        {conn, session_id}
      end

    # Process only experiments that aren't already in trials
    new_experiments = Enum.reject(experiment_names, &Map.has_key?(existing_trials, &1))

    new_variations =
      Enum.reduce(new_experiments, %{}, fn experiment_name, acc ->
        case get_session_exp_variation_by_id(session_id, experiment_name) do
          nil -> acc
          {:error, _reason} -> acc
          variation -> Map.put(acc, experiment_name, variation.name)
        end
      end)

    # Merge existing and new variations
    updated_trials = Map.merge(existing_trials, new_variations)
    conn = Plug.Conn.assign(conn, :ex_abby_trials, updated_trials)

    {conn, updated_trials}
  end

  @doc """
  Retrieves or assigns variations for multiple user-based experiments.
  Returns a map of %{experiment_name => variation_name}.
  """
  def get_user_exp_variations(%{id: user_id}, experiment_names)
      when is_list(experiment_names) and is_integer(user_id) do
    Enum.map(experiment_names, fn experiment_name ->
      variation = get_user_exp_variation(%{id: user_id}, experiment_name)
      {experiment_name, variation.name}
    end)
    |> Map.new()
  end

  @doc """
  Retrieves or assigns a variation for a user-based experiment,
  searching trials by user_id.
  """
  def get_user_exp_variation(%{id: user_id}, experiment_name) when is_integer(user_id) do
    {variation, _status} = Experiments.get_or_create_user_trial(experiment_name, user_id)
    variation
  end

  @doc """
  Sets a specific variation for a session-based experiment.
  Returns {:ok, trial} if successful, {:error, reason} otherwise.
  """
  def set_session_exp_variation(conn, experiment_name, variation_name) do
    session_id = Plug.Conn.get_session(conn, @session_key)

    if is_nil(session_id) do
      {conn, {:error, :no_session_id}}
    else
      case Experiments.set_session_trial_variation(session_id, experiment_name, variation_name) do
        {:ok, trial} ->
          existing_trials = Map.get(conn.assigns, :ex_abby_trials, %{})
          updated_trials = Map.put(existing_trials, experiment_name, variation_name)
          conn = Plug.Conn.assign(conn, :ex_abby_trials, updated_trials)
          {conn, {:ok, trial}}

        error ->
          {conn, error}
      end
    end
  end

  @doc """
  Sets a specific variation for a user-based experiment.
  Returns {:ok, trial} if successful, {:error, reason} otherwise.
  """
  def set_user_exp_variation(%{id: user_id}, experiment_name, variation_name)
      when is_integer(user_id) do
    with experiment when not is_nil(experiment) <-
           Experiments.get_experiment_by_name(experiment_name),
         variation when not is_nil(variation) <-
           Experiments.get_variation_by_name(experiment_name, variation_name),
         trial when not is_nil(trial) <- Experiments.get_trial_by_user(experiment.id, user_id) do
      Experiments.update_trial_variation(trial.id, variation.id)
    else
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Retrieves variations for multiple session-based experiments using session ID directly.
  Returns a map of %{experiment_name => variation_name}.
  """
  def get_session_exp_variations_by_id(session_id, experiment_names) when is_list(experiment_names) do
    Enum.reduce(experiment_names, %{}, fn experiment_name, acc ->
      case get_session_exp_variation_by_id(session_id, experiment_name) do
        nil -> acc
        {:error, _reason} -> acc
        variation -> Map.put(acc, experiment_name, variation.name)
      end
    end)
  end

  @doc """
  Gets or creates a variation for a session ID.
  """
  def get_session_exp_variation_by_id(session_id, experiment_name) do
    case Experiments.get_or_create_session_trial(experiment_name, session_id) do
      {:error, :experiment_not_found} = error ->
        Logger.error("Experiment not in database: #{experiment_name} #{inspect(error)}")

        error

      {:error, reason} = error ->
        Logger.error("Failed to get/create session trial: #{experiment_name} #{inspect(reason)}")

        error

      {variation, _status} ->
        variation
    end
  end

  @doc """
  Records successes for multiple session-based experiments.
  """
  def record_successes_for_session(conn, experiment_names, opts \\ [])
      when is_list(experiment_names) do
    session_id = Plug.Conn.get_session(conn, @session_key)
    ExAbby.Experiments.record_session_successes(session_id, experiment_names, opts)
  end

  @doc """
  Records successes for multiple experiments with a specific session ID.
  Returns a map of %{experiment_name => result} where result is {:ok, trial} or {:error, reason}
  """
  def record_successes_for_session_id(session_id, experiment_names, opts \\ [])
      when is_list(experiment_names) do
    Enum.map(experiment_names, fn experiment_name ->
      result = record_success_for_session_id(session_id, experiment_name, opts)
      {experiment_name, result}
    end)
    |> Map.new()
  end

  @doc """
  Records a success for a specific session ID.
  """
  def record_success_for_session_id(session_id, experiment_name, opts \\ [])

  def record_success_for_session_id(session_id, experiment_name, opts) do
    with experiment when not is_nil(experiment) <-
           Experiments.get_experiment_by_name(experiment_name),
         trial when not is_nil(trial) <-
           Experiments.get_trial_by_session(experiment.id, session_id) do
      Experiments.record_success(trial, opts)
      {:ok, trial}
    else
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Records a success for the session-based experiment.
  """
  def record_success_for_session(conn, experiment_name, opts \\ []) do
    session_id = Plug.Conn.get_session(conn, @session_key)

    if is_nil(session_id) do
      {:error, :no_session_id}
    else
      record_success_for_session_id(session_id, experiment_name, opts)
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end

  @doc """
  Links session-based trials to a user for a Phoenix controller.
  """
  def link_session_to_user_conn(conn, user, experiments) do
    session_id = Plug.Conn.get_session(conn, @session_key)
    
    if session_id do
      user_id = case user do
        %{id: id} when is_integer(id) -> id
        id when is_integer(id) -> id
        _ -> nil
      end
      
      if user_id do
        case Experiments.link_session_to_user(session_id, user_id, experiments) do
          {:ok, results} ->
            conn = Plug.Conn.assign(conn, :ex_abby_link_results, results)
            conn
          {:error, details} ->
            Logger.warning("Failed to link some session trials to user: #{inspect(details)}")
            conn = Plug.Conn.assign(conn, :ex_abby_link_results, {:error, details})
            conn
        end
      else
        Logger.error("Invalid user provided to link_session_to_user_conn")
        conn
      end
    else
      Logger.warning("No session ID found when trying to link to user")
      conn
    end
  end
end
