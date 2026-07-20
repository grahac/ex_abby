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

    if bot?(socket) do
      assign_bot_fallback(socket, existing_trials, experiment_names, bot_name(socket))
    else
      assign_human_variations(socket, existing_trials, experiment_names)
    end
  end

  defp assign_human_variations(socket, existing_trials, experiment_names) do
    if socket.assigns.ex_abby_session_id do
      # Process only experiments that aren't already in trials
      new_experiments = Enum.reject(experiment_names, &Map.has_key?(existing_trials, &1))

      new_variations =
        Enum.reduce(new_experiments, %{}, fn experiment_name, acc ->
          case get_or_restore_session_exp_variation_by_id(
                 socket.assigns.ex_abby_session_id,
                 experiment_name
               ) do
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
      bot?(socket) ->
        {:error, :bot_excluded, socket}

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
    bot_status = Map.get(session, "ex_abby_bot", :human)

    socket
    |> assign(:ex_abby_session_id, session_id)
    |> assign(:ex_abby_bot, bot_status)
    |> assign(:ex_abby_trials, %{})
  end

  def record_successes_for_session_lv(socket, experiment_names, opts \\ [])
      when is_list(experiment_names) do
    cond do
      bot?(socket) ->
        {:error, %{successful: [], failed: experiment_names}}

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

  defp get_or_restore_session_exp_variation_by_id(session_id, experiment_name),
    do: PhoenixHelper.get_or_restore_session_exp_variation_by_id(session_id, experiment_name)

  @doc """
  Links session-based trials to a user for a LiveView socket.
  """
  def link_session_to_user_lv(socket, user, experiments) do
    if bot?(socket) do
      assign(socket, :ex_abby_link_results, {:error, :bot_excluded})
    else
      link_human_session_to_user(socket, user, experiments)
    end
  end

  defp link_human_session_to_user(socket, user, experiments) do
    session_id = socket.assigns[:ex_abby_session_id]

    if session_id do
      user_id =
        case user do
          %{id: id} when is_integer(id) -> id
          id when is_integer(id) -> id
          _ -> nil
        end

      if user_id do
        case Experiments.link_session_to_user(session_id, user_id, experiments) do
          {:ok, results} ->
            assign(socket, :ex_abby_link_results, results)

          {:error, details} ->
            Logger.warning("Failed to link some session trials to user: #{inspect(details)}")
            assign(socket, :ex_abby_link_results, {:error, details})
        end
      else
        Logger.error("Invalid user provided to link_session_to_user_lv")
        socket
      end
    else
      Logger.warning("No session ID found when trying to link to user")
      socket
    end
  end

  defp assign_bot_fallback(socket, existing_trials, experiment_names, bot_name) do
    new_experiments = Enum.reject(experiment_names, &Map.has_key?(existing_trials, &1))

    trials =
      Enum.reduce(new_experiments, %{}, fn experiment_name, trials ->
        case PhoenixHelper.bot_fallback_variation_for_experiment(experiment_name) do
          nil ->
            trials

          fallback_variation ->
            PhoenixHelper.emit_excluded_assignment(experiment_name, bot_name)
            Map.put(trials, experiment_name, fallback_variation)
        end
      end)

    assign(socket, :ex_abby_trials, Map.merge(existing_trials, trials))
  end

  defp bot?(socket), do: not is_nil(bot_name(socket))

  defp bot_name(socket) do
    case socket.assigns[:ex_abby_bot] do
      {:bot, bot_name} when is_atom(bot_name) -> bot_name
      _ -> nil
    end
  end
end
