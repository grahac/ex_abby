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
    <style>
      .experiments-container {
        max-width: 1280px;
        margin: 0 auto;
        padding: 1.5rem;
      }

      .experiments-header {
        margin-bottom: 2rem;
      }

      .experiments-title {
        font-size: 1.875rem;
        font-weight: bold;
        color: #1e3a8a;
      }

      .experiments-table {
        width: 100%;
        border-collapse: collapse;
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
        border-radius: 0.5rem;
      }

      .experiments-table th {
        background-color: #eff6ff;
        padding: 0.75rem 1.5rem;
        text-align: left;
        font-size: 0.75rem;
        font-weight: 500;
        color: #1d4ed8;
        text-transform: uppercase;
        letter-spacing: 0.05em;
      }

      .experiments-table td {
        padding: 1rem 1.5rem;
        border-top: 1px solid #e5e7eb;
      }

      .experiments-table tbody tr:hover {
        background-color: #eff6ff;
      }

      .view-link {
        color: #2563eb;
        text-decoration: none;
        font-weight: 500;
      }

      .view-link:hover {
        color: #1d4ed8;
        text-decoration: underline;
      }

      .header-container {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 2rem;
      }

      .trials-button {
        background-color: #2563eb;
        color: white;
        padding: 0.75rem 1.5rem;
        border-radius: 0.375rem;
        text-decoration: none;
        font-weight: 500;
      }

      .trials-button:hover {
        background-color: #1d4ed8;
      }

      .filter-tabs {
        display: flex;
        gap: 0;
        margin-bottom: 1.5rem;
        border-bottom: 2px solid #e5e7eb;
      }

      .tab-button {
        padding: 0.75rem 1.5rem;
        border: none;
        background: transparent;
        cursor: pointer;
        font-weight: 500;
        color: #6b7280;
        border-bottom: 2px solid transparent;
        margin-bottom: -2px;
      }

      .tab-button:hover {
        color: #1d4ed8;
      }

      .tab-button.active {
        color: #1d4ed8;
        border-bottom-color: #1d4ed8;
      }

      .status-active {
        color: #059669;
        font-weight: 500;
      }

      .status-archived {
        color: #9ca3af;
        font-weight: 500;
      }

    </style>


    <div class="experiments-container">
      <div class="header-container">
        <h1 class="experiments-title">ExAbby Experiments</h1>
        <.link navigate="trials" class="trials-button">
          Edit Trials for Session
        </.link>
      </div>

      <div class="filter-tabs">
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
      </div>

      <table class="experiments-table">
        <thead>
          <tr>
            <th>Actions</th>
            <th>Experiment Name</th>
            <th>Description</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          <%= for e <- @experiments do %>
            <tr>
              <td>
                <.link patch={"#{e.id}"} class="view-link">
                  View
                </.link>
              </td>
              <td>{e.name}</td>
              <td>{e.description}</td>
              <td>
                <%= if e.archived_at do %>
                  <span class="status-archived">Archived</span>
                <% else %>
                  <span class="status-active">Active</span>
                <% end %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
