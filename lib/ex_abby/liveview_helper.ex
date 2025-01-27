defmodule ExAbby.LiveViewHelper do
  @moduledoc """
  Functions to handle A/B testing in a LiveView scenario:
  - Using session-based logic, but with no direct `conn`
  - Checking `connected?(socket)` before creating/recording
  """

  alias ExAbby.PhoenixHelper
  @session_key "ex_abby_session_id"
  import Phoenix.Component, only: [assign: 3]

  @doc """
  For a LiveView mount:
      socket = ExAbby.LiveViewHelper.fetch_session_exp_variation_lv(socket, session, "my_experiment")

  1. Checks if `connected?(socket)` (true once the WS is established)
  2. If connected, reads `ex_abby_session_id` from `session`
  3. Calls the underlying function to get or create a trial
  4. Assigns `:ab_variation` in the socket
  5. Returns the updated socket
  """
  def fetch_session_exp_variation_lv(socket, session, experiment_name) do
    if Phoenix.LiveView.connected?(socket) do
      # Get existing trials map or initialize empty map
      existing_trials = Map.get(socket.assigns, :ex_abby_trials, %{})

      # Return early if we already have this experiment's variation
      if Map.has_key?(existing_trials, experiment_name) do
        socket
      else
        session_id = Map.get(session, @session_key)

        if session_id do
          # Store session_id in assigns
          socket = assign(socket, :ex_abby_session_id, session_id)
          # Re-use the function from PhoenixHelper that takes a session_id
          variation = get_session_exp_variation_by_id(session_id, experiment_name)
          # Store just the variation name for simpler access
          updated_trials = Map.put(existing_trials, experiment_name, variation.name)

          assign(socket, :ex_abby_trials, updated_trials)
        else
          socket
          |> assign(:ex_abby_session_id, nil)
          |> assign(:ex_abby_trials, %{})
        end
      end
    else
      socket
      |> assign(:ex_abby_session_id, nil)
      |> assign(:ex_abby_trials, %{})
    end
  end

  @doc """
  For a LiveView event:
      ExAbby.LiveViewHelper.record_success_for_session_lv(socket, session, "my_experiment")

  1. Checks if `connected?(socket)`
  2. If connected, reads session_id from session
  3. Calls the function that increments success_count
  4. Returns {:ok, trial} or {:error, reason}
  """
  def record_success_for_session_lv(socket, experiment_name, opts \\ []) do
    if Phoenix.LiveView.connected?(socket) do
      if session_id = socket.assigns[:ex_abby_session_id] do
        PhoenixHelper.record_success_for_session_id(session_id, experiment_name, opts)
      else
        {:error, :no_session_id}
      end
    else
      {:error, :socket_not_connected}
    end
  end

  # ------------------------------------------------------------------
  # Because PhoenixHelper's session-based picking is with conn, let's
  # create a small function that re-uses the lower-level picking logic:
  # ------------------------------------------------------------------

  defp get_session_exp_variation_by_id(session_id, experiment_name) do
    # We can re-use the logic from PhoenixHelper by either:
    # 1) Exposing a function that directly handles session_id
    # 2) Or replicate it here. For demonstration, let's call a function that
    #    we assume is in PhoenixHelper:

    # We'll define 'PhoenixHelper.get_session_exp_variation_by_id/2'
    # or you can replicate the code if you prefer.

    PhoenixHelper.get_session_exp_variation_by_id(session_id, experiment_name)
  end
end
