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
    session_id = Plug.Conn.get_session(conn, @session_key)

    {conn, session_id} =
      if is_nil(session_id) do
        new_id = generate_session_id()
        {Plug.Conn.put_session(conn, @session_key, new_id), new_id}
      else
        {conn, session_id}
      end

    variation = get_session_exp_variation_by_id(session_id, experiment_name)
    {conn, variation}
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
    experiment = Experiments.get_or_create_experiment(experiment_name)
    {variation, _status} = Experiments.get_or_create_session_trial(experiment.id, session_id)
    variation
  end

  @doc """
  Records a success for the session-based experiment.
  """
  def record_success_for_session(conn, experiment_name) do
    session_id = Plug.Conn.get_session(conn, @session_key)

    if is_nil(session_id) do
      {:error, :no_session_id}
    else
      record_success_for_session_id(session_id, experiment_name)
    end
  end

  @doc """
  Records a success for a specific session ID.
  """
  def record_success_for_session_id(session_id, experiment_name) do
    with experiment when not is_nil(experiment) <-
           Experiments.get_experiment_by_name(experiment_name),
         trial when not is_nil(trial) <-
           Experiments.get_trial_by_session(experiment.id, session_id) do
      Experiments.record_success(trial)
      {:ok, trial}
    else
      nil -> {:error, :not_found}
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
