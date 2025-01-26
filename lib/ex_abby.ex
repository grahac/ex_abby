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

  ## Examples:
      # In Phoenix controller:
      ExAbby.record_success(conn, "experiment_name")

      # In LiveView:
      ExAbby.record_success(socket, session, "experiment_name")

      # For user-based:
      ExAbby.record_success(user, "experiment_name")
  """
  def record_success(%Plug.Conn{} = conn, experiment_name) do
    ExAbby.PhoenixHelper.record_success_for_session(conn, experiment_name)
  end

  def record_success(%Phoenix.LiveView.Socket{} = socket, experiment_name) do
    ExAbby.LiveViewHelper.record_success_for_session_lv(socket, experiment_name)
  end

  def record_success(%{id: user_id} = user, experiment_name) when is_integer(user_id) do
    ExAbby.Experiments.record_success_for_user(user, experiment_name)
  end

  # Admin/setup functions
  defdelegate upsert_experiment_and_update_weights(experiment_name, description, variations),
    to: ExAbby.Experiments
end
