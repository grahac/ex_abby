defmodule ExAbby.Live.ExperimentIndexLive do
  @moduledoc """
  Simple LiveView listing all ex_abby experiments.
  """
  use Phoenix.LiveView
  alias ExAbby.Experiments

  @spec mount(any(), any(), map()) :: {:ok, map()}
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:filter, :active)
     |> assign(:experiments, Experiments.list_experiments(status: :active))
     |> assign(:page_title, "ExAbby - Index")}
  end

  def handle_event("filter", %{"status" => status}, socket) do
    status_atom = String.to_existing_atom(status)

    {:noreply,
     socket
     |> assign(:filter, status_atom)
     |> assign(:experiments, Experiments.list_experiments(status: status_atom))}
  end

  def render(assigns) do
    ~H"""
    <ExAbby.Live.AdminStyle.styles />
    <style>
      .ex-abby-admin .ex-abby-index__name {
        font-weight: 600;
      }

      .ex-abby-admin .filter-tabs {
        display: flex;
        gap: 0.25rem;
        margin-bottom: 1rem;
      }

      .ex-abby-admin .tab-button {
        padding: 0.5rem 0.875rem;
        border: none;
        border-radius: 9999px;
        background: transparent;
        color: var(--ex-abby-color-ink-soft);
        cursor: pointer;
        font-size: 0.875rem;
        font-weight: 500;
      }

      .ex-abby-admin .tab-button:hover {
        background: var(--ex-abby-color-surface);
        color: var(--ex-abby-color-ink);
      }

      .ex-abby-admin .tab-button.active {
        background: var(--ex-abby-color-accent-wash);
        color: var(--ex-abby-color-ink);
      }

      .ex-abby-admin .ex-abby-visually-hidden {
        position: absolute;
        width: 1px;
        height: 1px;
        margin: -1px;
        padding: 0;
        overflow: hidden;
        clip: rect(0, 0, 0, 0);
        white-space: nowrap;
        border: 0;
      }

      .ex-abby-admin .ex-abby-row-link {
        position: relative;
        cursor: pointer;
      }

      .ex-abby-admin .ex-abby-row-link__anchor {
        color: var(--ex-abby-color-ink);
        text-decoration: none;
      }

      /* Stretch the row's link across the entire row so a click anywhere on
         the row navigates to the experiment detail page. */
      .ex-abby-admin .ex-abby-row-link__anchor::after {
        content: "";
        position: absolute;
        inset: 0;
      }

      .ex-abby-admin .ex-abby-row-link__chevron {
        width: 2.5rem;
        color: var(--ex-abby-color-soft-slate);
        text-align: right;
      }

      .ex-abby-admin .ex-abby-row-link__chevron svg {
        vertical-align: middle;
      }

      .ex-abby-admin .ex-abby-row-link:hover .ex-abby-row-link__chevron {
        color: var(--ex-abby-color-accent);
      }
    </style>

    <div class="ex-abby-admin">
      <main class="ex-abby-admin__shell">
        <header class="ex-abby-admin__header">
          <div>
            <h1 class="ex-abby-admin__title">ExAbby Experiments</h1>
            <p class="ex-abby-admin__subtitle">
              Monitor experiment status, inspect results, and manage test assignments.
            </p>
          </div>
          <.link navigate="trials" class="ex-abby-button ex-abby-button--primary">
            Edit Trials for Session
          </.link>
        </header>

        <nav class="filter-tabs" aria-label="Filter experiments">
          <button
            class={"tab-button #{if @filter == :active, do: "active"}"}
            phx-click="filter"
            phx-value-status="active"
          >
            Active
          </button>
          <button
            class={"tab-button #{if @filter == :archived, do: "active"}"}
            phx-click="filter"
            phx-value-status="archived"
          >
            Archived
          </button>
          <button
            class={"tab-button #{if @filter == :all, do: "active"}"}
            phx-click="filter"
            phx-value-status="all"
          >
            All
          </button>
        </nav>

        <div class="ex-abby-table-frame">
          <table class="ex-abby-table">
            <thead>
              <tr>
                <th>Experiment Name</th>
                <th>Description</th>
                <th>Status</th>
                <th><span class="ex-abby-visually-hidden">Open</span></th>
              </tr>
            </thead>
            <tbody>
              <%= for e <- @experiments do %>
                <tr class="ex-abby-row-link">
                  <td class="ex-abby-index__name">
                    <.link navigate={"#{e.id}"} class="ex-abby-row-link__anchor">{e.name}</.link>
                  </td>
                  <td>{e.description}</td>
                  <td>
                    <%= if e.archived_at do %>
                      <span class="ex-abby-status ex-abby-status--muted">Archived</span>
                    <% else %>
                      <span class="ex-abby-status ex-abby-status--success">Active</span>
                    <% end %>
                  </td>
                  <td class="ex-abby-row-link__chevron">
                    <svg
                      width="16"
                      height="16"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      aria-hidden="true"
                    >
                      <path d="m9 18 6-6-6-6" />
                    </svg>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if Enum.empty?(@experiments) do %>
            <div class="ex-abby-empty-state">No experiments match this filter.</div>
          <% end %>
        </div>
      </main>
    </div>
    """
  end
end
