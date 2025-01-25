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
    <div>
      <h1>ExAbby Experiments</h1>
      <table>
        <thead>
          <tr>
            <th>Experiment Name</th>
            <th>Description</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
        <%= for e <- @experiments do %>
          <tr>
            <td><%= e.name %></td>
            <td><%= e.description %></td>
    <td>
    <.link patch={"#{e.id}"}>
    View
    </.link>
    </td>
          </tr>
        <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
