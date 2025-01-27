defmodule ExAbby.PhoenixHelper do
  @moduledoc """
  Provides Phoenix-based A/B testing functions that operate with a Plug.Conn
  """

  alias ExAbby.Experiments
  @session_key "ex_abby_session_id"

  @doc """
  Retrieves or assigns a variation for a session-based experiment,
  using the session_id found in `conn`.
  Returns {conn, variation}.
  """
  def get_session_exp_variation(conn, experiment_name) do
    # Get existing trials map or initialize empty map
    existing_trials = Map.get(conn.assigns, :ex_abby_trials, %{})

    # Return early if we already have this experiment's variation
    if Map.has_key?(existing_trials, experiment_name) do
      {conn, %{name: Map.get(existing_trials, experiment_name)}}
    else
      session_id = Plug.Conn.get_session(conn, @session_key)

      {conn, session_id} =
        if is_nil(session_id) do
          new_id = generate_session_id()
          {Plug.Conn.put_session(conn, @session_key, new_id), new_id}
        else
          {conn, session_id}
        end

      variation = get_session_exp_variation_by_id(session_id, experiment_name)
      # Store just the variation name for simpler access
      updated_trials = Map.put(existing_trials, experiment_name, variation.name)
      conn = Plug.Conn.assign(conn, :ex_abby_trials, updated_trials)

      {conn, variation.name}
    end
  end

  @doc """
  Retrieves or assigns a variation for a user-based experiment,
  searching trials by user_id.
  """
  def get_user_exp_variation(%{id: user_id}, experiment_name) when is_integer(user_id) do
    experiment = Experiments.get_or_create_experiment(experiment_name)
    {variation, _status} = Experiments.get_or_create_user_trial(experiment.id, user_id)
    variation
  end

  @doc """
  Gets or creates a variation for a session ID.
  """
  def get_session_exp_variation_by_id(session_id, experiment_name) do
    {variation, _status} = Experiments.get_or_create_session_trial(experiment_name, session_id)
    variation
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

  @doc """
  Records a success for a specific session ID.
  """
  def record_success_for_session_id(session_id, experiment_name, opts \\ []) do
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

  defp generate_session_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
