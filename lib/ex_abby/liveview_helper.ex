defmodule ExAbby.LiveViewHelper do
  @moduledoc """
  Functions to handle A/B testing in a LiveView scenario:
  - Using session-based logic, but with no direct `conn`
  - Checking `connected?(socket)` before creating/recording
  """
  import Phoenix.Component, only: [assign: 3]
  alias ExAbby.PhoenixHelper
  alias ExAbby.Experiments
  require Logger
  @session_key "ex_abby_session_id"

  @doc """



  For a LiveView mount with multiple experiments:
      socket = ExAbby.LiveViewHelper.fetch_session_exp_variations_lv(socket, session, ["exp1", "exp2"])

  1. Checks if `connected?(socket)` (true once the WS is established)
  2. If connected, reads `ex_abby_session_id` from `session`
  3. Calls the underlying function to get or create a trial
  4. Assigns `:ab_variation` in the socket
  5. Returns the updated socket

  Returns socket with :ex_abby_trials assigned as a map of %{experiment_name => variation_name}
  """
  def fetch_session_exp_variations_lv(socket, session, experiment_names)
      when is_list(experiment_names) do
    # Get existing trials map or initialize empty map
    existing_trials = Map.get(socket.assigns, :ex_abby_trials, %{})

    socket = save_session_data(socket, session)

    if socket.assigns.ex_abby_session_id do
      # Process only experiments that aren't already in trials
      new_experiments = Enum.reject(experiment_names, &Map.has_key?(existing_trials, &1))

      new_variations =
        Enum.reduce(new_experiments, %{}, fn experiment_name, acc ->
          case get_session_exp_variation_by_id(socket.assigns.ex_abby_session_id, experiment_name) do
            %{name: name} -> Map.put(acc, experiment_name, name)
            {:error, :experiment_not_found} -> acc
          end
        end)

      # Merge existing and new variations
      updated_trials = Map.merge(existing_trials, new_variations)
      assign(socket, :ex_abby_trials, updated_trials)
    else
      Logger.warning(
        "Could not find Session token.  Make sure you have the ExAbby Router Plug installed."
      )

      socket
    end
  end

  @doc """
  Sets a specific variation for a session-based experiment in LiveView.
  Returns {:ok, trial} if successful, {:error, reason} otherwise.
  """
  def set_session_exp_variation_lv(socket, experiment_name, variation_name) do
    cond do
      not Phoenix.LiveView.connected?(socket) ->
        {:error, :not_connected, socket}

      is_nil(socket.assigns[:ex_abby_session_id]) ->
        {:error, :no_session_id, socket}

      true ->
        case Experiments.set_session_trial_variation(
               socket.assigns.ex_abby_session_id,
               experiment_name,
               variation_name
             ) do
          {:ok, trial} ->
            existing_trials = Map.get(socket.assigns, :ex_abby_trials, %{})
            updated_trials = Map.put(existing_trials, experiment_name, variation_name)
            updated_socket = assign(socket, :ex_abby_trials, updated_trials)
            {:ok, trial, updated_socket}

          {:error, reason} ->
            {:error, reason, socket}
        end
    end
  end

  def save_session_data(%Phoenix.LiveView.Socket{} = socket, session) do
    session_id = Map.get(session, @session_key)

    socket
    |> assign(:ex_abby_session_id, session_id)
    |> assign(:ex_abby_trials, %{})
  end

  def record_successes_for_session_lv(socket, experiment_names, opts \\ [])
      when is_list(experiment_names) do
    cond do
      not Phoenix.LiveView.connected?(socket) ->
        {:error, %{successful: [], failed: experiment_names}}

      is_nil(socket.assigns[:ex_abby_session_id]) ->
        {:error, %{successful: [], failed: experiment_names}}

      true ->
        ExAbby.Experiments.record_session_successes(
          socket.assigns.ex_abby_session_id,
          experiment_names,
          opts
        )
    end
  end

  def record_success_for_session_lv(socket, experiment_name, opts \\ []) do
    record_successes_for_session_lv(socket, [experiment_name], opts)
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
