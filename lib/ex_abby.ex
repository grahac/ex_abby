defmodule ExAbby do
  @moduledoc """
  ExAbby: an Elixir/Phoenix library for A/B testing.

  Provides a unified interface for both Phoenix controllers and LiveView,
  automatically detecting and handling each case appropriately.
  """

  @doc """
  Gets or creates a trial for a session-based experiment.

  ## Examples:
      # In Phoenix controller:
      {conn, variation} = ExAbby.get_variation(conn, "experiment_name")

      # In LiveView:
      socket = ExAbby.get_variation(socket, session, "experiment_name")

      # For user-based:
      variation = ExAbby.get_variation(user, "experiment_name")
  """
  def get_variation(%Plug.Conn{} = conn, experiment_name) do
    ExAbby.PhoenixHelper.get_session_exp_variation(conn, experiment_name)
  end

  def get_variation(%{id: user_id} = user, experiment_name) when is_integer(user_id) do
    ExAbby.PhoenixHelper.get_user_exp_variation(user, experiment_name)
  end

  def get_variation(%Phoenix.LiveView.Socket{} = socket, session, experiment_name) do
    ExAbby.LiveViewHelper.fetch_session_exp_variation_lv(socket, session, experiment_name)
  end

  @doc """
  Records a success for an experiment.

  ## Options
    * `:amount` - Optional numeric value to track with the success (default: 0.0)
    * `:success_type` - Type of success to record, either `:success1` or `:success2` (default: `:success1`)

  ## Examples:
      # In Phoenix controller:
      ExAbby.record_success(conn, "experiment_name")
      ExAbby.record_success(conn, "experiment_name", amount: 10.5)
      ExAbby.record_success(conn, "experiment_name", success_type: :success2)

      # In LiveView:
      ExAbby.record_success(socket, "experiment_name")
      ExAbby.record_success(socket, "experiment_name", amount: 10.5, success_type: :success2)

      # For user-based:
      ExAbby.record_success(user, "experiment_name")
  """
  def record_success(context, experiment_name, opts \\ [])

  def record_success(%Plug.Conn{} = conn, experiment_name, opts) do
    ExAbby.PhoenixHelper.record_success_for_session(conn, experiment_name, opts)
  end

  def record_success(%Phoenix.LiveView.Socket{} = socket, experiment_name, opts) do
    ExAbby.LiveViewHelper.record_success_for_session_lv(socket, experiment_name, opts)
  end

  def record_success(%{id: user_id} = user, experiment_name, opts) when is_integer(user_id) do
    ExAbby.Experiments.record_success_for_user(user, experiment_name, opts)
  end

  # Admin/setup functions
  defdelegate upsert_experiment_and_update_weights(experiment_name, description, variations),
    to: ExAbby.Experiments
end
