defmodule ExAbby.Live.ExperimentIndexLive do
  @moduledoc """
  Simple LiveView listing all ex_abby experiments.
  """
  use Phoenix.LiveView
  alias ExAbby.Experiments

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :experiments, Experiments.list_experiments())}
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
    </style>

    <div class="experiments-container">
      <div class="experiments-header">
        <h1 class="experiments-title">ExAbby Experiments</h1>
      </div>

      <table class="experiments-table">
        <thead>
          <tr>
            <th>Actions</th>
            <th>Experiment Name</th>
            <th>Description</th>
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
              <td><%= e.name %></td>
              <td><%= e.description %></td>

            </tr>

          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
