defmodule ExAbby.Live.TrialManagementLive do
  use Phoenix.LiveView
  use Phoenix.Component
  alias ExAbby.Experiments
  alias ExAbby.LiveViewHelper

  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:user_trials_expanded, true)
      |> assign(:session_trials_expanded, true)
      |> assign(:page_title, "ExAbby - Trial page")
      |> LiveViewHelper.save_session_data(session)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    user_id =
      cond do
        params["user_id"] -> String.to_integer(params["user_id"])
        socket.assigns[:current_user] -> socket.assigns.current_user.id
        true -> nil
      end

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(
        :user_experiments,
        if(user_id, do: Experiments.list_experiments_with_user_trials(user_id), else: [])
      )
      |> assign(
        :session_experiments,
        Experiments.list_experiments_with_session_trials(socket.assigns.ex_abby_session_id)
      )

    {:noreply, socket}
  end

  def handle_event("toggle-user-trials", _, socket) do
    {:noreply, assign(socket, :user_trials_expanded, !socket.assigns.user_trials_expanded)}
  end

  def handle_event("toggle-session-trials", _, socket) do
    {:noreply, assign(socket, :session_trials_expanded, !socket.assigns.session_trials_expanded)}
  end

  def handle_event(
        "update-variation",
        %{"trial_id" => trial_id, "variation_id" => variation_id},
        socket
      ) do
    {trial_id, _} = Integer.parse(trial_id)
    {variation_id, _} = Integer.parse(variation_id)

    case Experiments.update_trial_variation(trial_id, variation_id) do
      {:ok, _updated_trial} -> {:noreply, socket}
      _ -> {:noreply, put_flash(socket, :error, "Failed to update variation")}
    end
  end

  def render(assigns) do
    ~H"""
       <style>
      .trial-container {
        max-width: 1280px;
        margin: 0 auto;
        padding: 1.5rem;
      }


      .back-button {
        display: inline-flex;
        padding: 0.5rem 1rem;
        background-color: #93c5fd;
        color: #1e3a8a;
        text-decoration: none;
        border-radius: 0.375rem;
        margin-bottom: 1rem;
        width: fit-content;
      }
      .back-button:hover {
        background-color: #60a5fa;
      }
      .section-header {
        display: flex;
        align-items: center;
        margin-bottom: 1rem;
      }

      .section-title {
        font-size: 1.5rem;
        font-weight: bold;
        color: #1e3a8a;
      }

      .toggle-button {
        margin-left: 0.5rem;
        background: none;
        border: none;
        color: #2563eb;
        cursor: pointer;
      }

      .experiment-card {
        background-color: white;
        padding: 1.5rem;
        border-radius: 0.5rem;
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
        margin-bottom: 1rem;
      }

      .experiment-header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        margin-bottom: 1.5rem;
      }

      .experiment-info {
        flex: 1;
      }

      .experiment-name {
        font-size: 1.25rem;
        font-weight: 600;
        color: #1e3a8a;
        margin-bottom: 0.5rem;
      }

      .experiment-description {
        color: #4b5563;
        font-size: 0.875rem;
        line-height: 1.4;
      }

      .trial-stats {
        text-align: right;
        min-width: 150px;
        max-width: 300px;
        font-size: 0.875rem;
        color: #2563eb;
        background-color: #f3f4f6;
        padding: 0.75rem;
        border-radius: 0.375rem;
      }

      .variation-list {
        display: flex;
        flex-wrap: wrap;
        gap: 1rem;
        margin-top: 1rem;
      }

      .variation-item {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        padding: 0.5rem 1rem;
        border: 1px solid #e5e7eb;
        border-radius: 0.375rem;
        cursor: pointer;
        transition: all 0.2s ease;
      }

      .variation-item:hover {
        background-color: #f3f4f6;
        border-color: #d1d5db;
      }

      .variation-item input[type="radio"] {
        margin: 0;
        cursor: pointer;
      }

      .variation-item span {
        font-size: 0.875rem;
        color: #374151;
      }

      .sections-wrapper {
        display: flex;
        flex-direction: column;
        gap: 2rem;
      }
    </style>

    <div class="trial-container">
      <div class="sections-wrapper">
      <.link patch={"index"} class="back-button">← Back to Experiments</.link>
        <.user_trials_section
          user_trials_expanded={@user_trials_expanded}
          user_id={@user_id}
          user_experiments={@user_experiments}
        />
        <.session_trials_section
          session_trials_expanded={@session_trials_expanded}
          ex_abby_session_id={@ex_abby_session_id}
          session_experiments={@session_experiments}
        />
      </div>
    </div>
    """
  end

  def user_trials_section(assigns) do
    ~H"""
    <div>
      <div class="flex items-center mb-4">
        <h2 class="text-xl font-bold">User Trials</h2>
        <button class="ml-2" phx-click="toggle-user-trials">
          <%= if @user_trials_expanded, do: "▼", else: "▶" %>
        </button>
      </div>

      <%= if @user_trials_expanded do %>
        <%= if @user_id do %>
          <%= if Enum.empty?(@user_experiments) do %>
            <div class="text-center text-gray-600 p-4">
              No experiments for this user.
            </div>
          <% else %>
            <div class="space-y-6">
              <%= for experiment <- @user_experiments do %>
                <.experiment_card
                  experiment={experiment}
                  trial={Experiments.get_trial_by_user(experiment.id, @user_id)}
                  type="experiment"
                />
              <% end %>
            </div>
          <% end %>
        <% else %>
          <div class="text-center text-gray-600 p-4">
            No user ID provided and no current user found.
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  def session_trials_section(assigns) do
    ~H"""
    <div>
      <div class="flex items-center mb-4">
        <h2 class="text-xl font-bold">Session Trials</h2>
        <button class="ml-2" phx-click="toggle-session-trials">
          <%= if @session_trials_expanded, do: "▼", else: "▶" %>
        </button>
      </div>

      <%= if @session_trials_expanded do %>
        <%= if Enum.empty?(@session_experiments) do %>
          <div style="text-align: center; padding: 1rem; color: #666;">
            No session experiments for this session.
          </div>
        <% else %>
          <div class="space-y-6">
            <%= for experiment <- @session_experiments do %>
              <.experiment_card
                experiment={experiment}
                trial={Experiments.get_trial_by_session(experiment.id, @ex_abby_session_id)}
                type="session-experiment"
              />
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  def experiment_card(assigns) do
    ~H"""
    <div class="experiment-card">
      <div class="experiment-header">
        <div class="experiment-info">
          <h3 class="experiment-name"><%= @experiment.name %></h3>
          <p class="experiment-description"><%= @experiment.description %></p>
        </div>
        <%= if @trial do %>
          <div class="trial-stats">
            <div>
              <%= @experiment.success1_label || "Success" %>: <%= @trial.success1_count %>
            </div>
            <div>
              <%= @experiment.success2_label || "Success" %>: <%= @trial.success2_count %>
            </div>
          </div>
        <% end %>
      </div>

      <div class="variation-list">
        <%= for variation <- @experiment.variations do %>
          <label class="variation-item">
            <input type="radio"
                   name={"#{@type}-#{@experiment.id}"}
                   value={variation.id}
                   checked={@trial && @trial.variation_id == variation.id}
                   phx-click="update-variation"
                   phx-value-trial_id={@trial && @trial.id}
                   phx-value-variation_id={variation.id}>
            <span><%= variation.name %></span>
          </label>
        <% end %>
      </div>
    </div>
    """
  end
end
