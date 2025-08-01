defmodule ExAbby do
  @moduledoc """
  ExAbby: an Elixir/Phoenix library for A/B testing.

  Provides a unified interface for both Phoenix controllers and LiveView,
  automatically detecting and handling each case appropriately.
  """

  @doc """
  Gets or creates trials for multiple experiments.

  ## Examples:
      # In Phoenix controller:
      {conn, variations} = ExAbby.get_variations(conn, ["exp1", "exp2"])

      # In LiveView:
      socket = ExAbby.get_variations(socket, session, ["exp1", "exp2"])

      # For user-based:
      variations = ExAbby.get_variations(user, ["exp1", "exp2"])
  """
  def get_variations(%Plug.Conn{} = conn, experiment_names) when is_list(experiment_names) do
    ExAbby.PhoenixHelper.get_session_exp_variations(conn, experiment_names)
  end

  def get_variations(%{id: user_id} = user, experiment_names)
      when is_list(experiment_names) and is_integer(user_id) do
    ExAbby.PhoenixHelper.get_user_exp_variations(user, experiment_names)
  end

  def get_variations(user_id, experiment_names)
      when is_integer(user_id) and is_list(experiment_names) do
    ExAbby.PhoenixHelper.get_user_exp_variations(%{id: user_id}, experiment_names)
  end

  def get_variations(session_id, experiment_names)
      when is_binary(session_id) and is_list(experiment_names) do
    ExAbby.PhoenixHelper.get_session_exp_variations_by_id(session_id, experiment_names)
  end

  def get_variations(%Phoenix.LiveView.Socket{} = socket, session, experiment_names)
      when is_list(experiment_names) do
    ExAbby.LiveViewHelper.fetch_session_exp_variations_lv(socket, session, experiment_names)
  end

  @doc """
  Sets a specific variation for an experiment.
  Returns {:ok, trial} if successful, {:error, reason} otherwise.

  ## Examples:
      # In Phoenix controller:
      {:ok, trial} = ExAbby.set_variation(conn, "experiment_name", "variation_name")

      # In LiveView:
      {:ok, trial} = ExAbby.set_variation(socket, "experiment_name", "variation_name")

      # For user-based:
      {:ok, trial} = ExAbby.set_variation(user, "experiment_name", "variation_name")
  """
  def set_variation(%Plug.Conn{} = conn, experiment_name, variation_name) do
    ExAbby.PhoenixHelper.set_session_exp_variation(conn, experiment_name, variation_name)
  end

  def set_variation(%Phoenix.LiveView.Socket{} = socket, experiment_name, variation_name) do
    ExAbby.LiveViewHelper.set_session_exp_variation_lv(socket, experiment_name, variation_name)
  end

  def set_variation(%{id: user_id} = user, experiment_name, variation_name)
      when is_integer(user_id) do
    ExAbby.PhoenixHelper.set_user_exp_variation(user, experiment_name, variation_name)
  end

  @doc """
  Gets or creates a trial for a single experiment. Convenience wrapper around get_variations.

  ## Examples:
      # In Phoenix controller:
      {conn, variation} = ExAbby.get_variation(conn, "experiment_name")

      # In LiveView:
      socket = ExAbby.get_variation(socket, session, "experiment_name")

      # For user-based:
      variation = ExAbby.get_variation(user, "experiment_name")
  """
  def get_variation(%Plug.Conn{} = conn, experiment_name) do
    {conn, variations} = get_variations(conn, [experiment_name])
    {conn, Map.get(variations, experiment_name)}
  end

  def get_variation(%{id: user_id} = user, experiment_name) when is_integer(user_id) do
    variations = get_variations(user, [experiment_name])
    Map.get(variations, experiment_name)
  end

  def get_variation(user_id, experiment_name) when is_integer(user_id) do
    variations = get_variations(user_id, [experiment_name])
    Map.get(variations, experiment_name)
  end

  def get_variation(session_id, experiment_name) when is_binary(session_id) do
    variations = get_variations(session_id, [experiment_name])
    Map.get(variations, experiment_name)
  end

  def get_variation(%Phoenix.LiveView.Socket{} = socket, session, experiment_name) do
    get_variations(socket, session, [experiment_name])
  end

  def set_variation(%Plug.Conn{} = conn, experiment_name) do
    {conn, variations} = get_variations(conn, [experiment_name])
    {conn, Map.get(variations, experiment_name)}
  end

  @spec save_session_data(Phoenix.LiveView.Socket.t(), map()) :: map()
  @doc """
  Saves session info to socket. Used on pages where you call success so you do not create a new experiment before you call results
  """

  defdelegate save_session_data(socket, session), to: ExAbby.LiveViewHelper

  @doc """
  Records successes for multiple experiments.

  ## Options
    * `:amount` - Optional numeric value to track with the success (default: 0.0)
    * `:success_type` - Type of success to record, either `:success1` or `:success2` (default: `:success1`)

  ## Examples:
      # In Phoenix controller:
      {:ok, results} = ExAbby.record_successes(conn, ["exp1", "exp2"])
      {:error, %{successful: ["exp1"], failed: ["exp2"]}} = ExAbby.record_successes(conn, ["exp1", "exp2"])

      # In LiveView:
      {:ok, results} = ExAbby.record_successes(socket, ["exp1", "exp2"])

      # For user-based:
      {:ok, results} = ExAbby.record_successes(user, ["exp1", "exp2"])

  Returns either:
    * `{:ok, %{experiment_name => {:ok, trial}}}` if all successful
    * `{:error, %{successful: [...], failed: [...]}}` if any failed
  """
  def record_successes(context, experiment_names, opts \\ [])

  def record_successes(%Plug.Conn{} = conn, experiment_names, opts)
      when is_list(experiment_names) do
    ExAbby.PhoenixHelper.record_successes_for_session(conn, experiment_names, opts)
  end

  def record_successes(%Phoenix.LiveView.Socket{} = socket, experiment_names, opts)
      when is_list(experiment_names) do
    ExAbby.LiveViewHelper.record_successes_for_session_lv(socket, experiment_names, opts)
  end

  def record_successes(%{id: user_id} = _user, experiment_names, opts)
      when is_list(experiment_names) and is_integer(user_id) do
    ExAbby.Experiments.record_user_successes(user_id, experiment_names, opts)
  end

  def record_successes(user_id, experiment_names, opts)
      when is_integer(user_id) and is_list(experiment_names) do
    ExAbby.Experiments.record_user_successes(user_id, experiment_names, opts)
  end

  def record_successes(session_id, experiment_names, opts)
      when is_binary(session_id) and is_list(experiment_names) do
    ExAbby.PhoenixHelper.record_successes_for_session_id(session_id, experiment_names, opts)
  end

  @doc """
  Records a success for a single experiment. Convenience wrapper around record_successes.
  """
  def record_success(context, experiment_name, opts \\ []) do
    record_successes(context, [experiment_name], opts)
  end

  # Admin/setup functions
  defdelegate upsert_experiment_and_update_weights(
                experiment_name,
                description,
                variations,
                opts \\ []
              ),
              to: ExAbby.Experiments
end
