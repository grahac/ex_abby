defmodule ExAbby.Live.TrialManagementLive do
  use Phoenix.LiveView
  alias ExAbby.Experiments
  alias ExAbby.LiveViewHelper

  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:user_trials_expanded, true)
      |> assign(:session_trials_expanded, true)
      |> assign(:page_title, "ExAbby - Trial page")
      |> assign(:standalone, Map.get(session, "ex_abby_standalone", false))
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
    <ExAbby.Live.AdminStyle.styles />
    <style>
      .ex-abby-admin .section-header {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        padding: 1rem 1.25rem;
        border-bottom: 1px solid var(--ex-abby-color-border);
      }

      .ex-abby-admin .section-title {
        margin: 0;
        color: var(--ex-abby-color-ink);
        font-family: Geist, "General Sans", Inter, ui-sans-serif, system-ui, sans-serif;
        font-size: 1.125rem;
        font-weight: 500;
        letter-spacing: -0.015em;
      }

      .ex-abby-admin .toggle-button {
        display: inline-flex;
        width: 2rem;
        height: 2rem;
        align-items: center;
        justify-content: center;
        padding: 0;
        background: transparent;
        border: 1px solid transparent;
        border-radius: 9999px;
        color: var(--ex-abby-color-ink-soft);
        cursor: pointer;
      }

      .ex-abby-admin .toggle-button:hover {
        background: var(--ex-abby-color-accent-wash);
        color: var(--ex-abby-color-ink);
      }

      .ex-abby-admin .trial-section__body {
        padding: 1.25rem;
      }

      .ex-abby-admin .experiment-card {
        padding: 1.25rem;
        background: var(--ex-abby-color-surface);
        border: 1px solid var(--ex-abby-color-border);
        border-radius: 10px;
      }

      .ex-abby-admin .experiment-card + .experiment-card {
        margin-top: 1rem;
      }

      .ex-abby-admin .experiment-header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        gap: 1rem;
        margin-bottom: 1rem;
      }

      .ex-abby-admin .experiment-info {
        flex: 1;
      }

      .ex-abby-admin .experiment-name {
        margin: 0;
        color: var(--ex-abby-color-ink);
        font-size: 1rem;
        font-weight: 600;
      }

      .ex-abby-admin .experiment-description {
        margin: 0.375rem 0 0;
        color: var(--ex-abby-color-ink-soft);
        font-size: 0.875rem;
        line-height: 1.5;
      }

      .ex-abby-admin .trial-stats {
        min-width: 10rem;
        padding: 0.75rem;
        background: var(--ex-abby-color-canvas);
        border: 1px solid var(--ex-abby-color-border);
        border-radius: 4px;
        color: var(--ex-abby-color-ink-soft);
        font-size: 0.8125rem;
        font-variant-numeric: tabular-nums;
        text-align: right;
      }

      .ex-abby-admin .variation-list {
        display: flex;
        flex-wrap: wrap;
        gap: 0.5rem;
      }

      .ex-abby-admin .variation-item {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        padding: 0.5rem 0.75rem;
        background: var(--ex-abby-color-surface);
        border: 1px solid var(--ex-abby-color-border-strong);
        border-radius: 9999px;
        cursor: pointer;
      }

      .ex-abby-admin .variation-item:hover {
        background: var(--ex-abby-color-canvas);
        border-color: var(--ex-abby-color-warm-slate);
      }

      .ex-abby-admin .variation-item input[type="radio"] {
        width: 1rem;
        height: 1rem;
        margin: 0;
        accent-color: var(--ex-abby-color-accent);
        cursor: pointer;
      }

      .ex-abby-admin .variation-item span {
        font-size: 0.875rem;
        color: var(--ex-abby-color-ink);
      }

      .ex-abby-admin .sections-wrapper {
        display: flex;
        flex-direction: column;
        gap: 1rem;
      }

      .ex-abby-admin .trial-page__back {
        width: fit-content;
        margin-bottom: 0.5rem;
      }

      @media (max-width: 640px) {
        .ex-abby-admin .experiment-header {
          flex-direction: column;
        }

        .ex-abby-admin .trial-stats {
          width: 100%;
          text-align: left;
        }
      }
    </style>

    <div class="ex-abby-admin">
      <main class="ex-abby-admin__shell">
        <header class="ex-abby-admin__header">
          <div>
            <h1 class="ex-abby-admin__title">Trial Assignments</h1>
            <p class="ex-abby-admin__subtitle">
              Inspect and change the variations assigned to this user and browser session.
            </p>
          </div>
        </header>

        <div class="sections-wrapper">
          <.link
            :if={!@standalone}
            navigate={"index"}
            class="ex-abby-button ex-abby-button--secondary trial-page__back"
          >
            ← Back to Experiments
          </.link>
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
      </main>
    </div>
    """
  end

  def user_trials_section(assigns) do
    ~H"""
    <section class="ex-abby-panel">
      <header class="section-header">
        <h2 class="section-title">User Trials</h2>
        <button
          class="toggle-button"
          phx-click="toggle-user-trials"
          aria-label="Toggle user trials"
          aria-expanded={to_string(@user_trials_expanded)}
        >
          <%= if @user_trials_expanded, do: "▼", else: "▶" %>
        </button>
      </header>

      <%= if @user_trials_expanded do %>
        <div class="trial-section__body">
          <%= if @user_id do %>
            <%= if Enum.empty?(@user_experiments) do %>
              <div class="ex-abby-empty-state">
                No experiments for this user.
              </div>
            <% else %>
              <div>
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
            <div class="ex-abby-empty-state">
              No user ID provided and no current user found.
            </div>
          <% end %>
        </div>
      <% end %>
    </section>
    """
  end

  def session_trials_section(assigns) do
    ~H"""
    <section class="ex-abby-panel">
      <header class="section-header">
        <h2 class="section-title">Session Trials</h2>
        <button
          class="toggle-button"
          phx-click="toggle-session-trials"
          aria-label="Toggle session trials"
          aria-expanded={to_string(@session_trials_expanded)}
        >
          <%= if @session_trials_expanded, do: "▼", else: "▶" %>
        </button>
      </header>

      <%= if @session_trials_expanded do %>
        <div class="trial-section__body">
          <%= if Enum.empty?(@session_experiments) do %>
            <div class="ex-abby-empty-state">
              No session experiments for this session.
            </div>
          <% else %>
            <div>
              <%= for experiment <- @session_experiments do %>
                <.experiment_card
                  experiment={experiment}
                  trial={Experiments.get_trial_by_session(experiment.id, @ex_abby_session_id)}
                  type="session-experiment"
                />
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </section>
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
