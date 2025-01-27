defmodule ExAbby.Live.ExperimentShowLive do
  @moduledoc """
  Shows a single experiment's variations, plus editing of weights.
  """
  alias ExAbby.Experiments
  use Phoenix.LiveView
  use Phoenix.Component

  def mount(%{"id" => id}, _session, socket) do
    socket = load_experiment(socket, String.to_integer(id))

    if(socket.assigns[:experiment]) do
      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: "/")}
    end
  end

  def render(assigns) do
    ~H"""
    <style>

      .back-button {
        display: inline-block;
        padding: 0.5rem 1rem;
        background-color: #93c5fd;
        color: #1e3a8a;
        text-decoration: none;
        border-radius: 0.375rem;
        margin-bottom: 1rem;
      }

      .back-button:hover {
        background-color: #60a5fa;
      }
      .experiment-container {
        max-width: 1280px;
        margin: 0 auto;
        padding: 1.5rem;
      }

      .experiment-header {
        margin-bottom: 2rem;
      }

      .experiment-title {
        font-size: 1.875rem;
        font-weight: bold;
        color: #1e3a8a;
      }

      .experiment-description {
        margin-top: 0.5rem;
        font-size: 1.125rem;
        color: #2563eb;
      }

      .experiment-table {
        width: 100%;
        border-collapse: collapse;
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
        border-radius: 0.5rem;
      }

      .experiment-table th {
        background-color: #eff6ff;
        padding: 0.75rem 1.5rem;
        text-align: left;
        font-size: 0.75rem;
        font-weight: 500;
        color: #1d4ed8;
        text-transform: uppercase;
        letter-spacing: 0.05em;
      }

      .experiment-table td {
        padding: 1rem 1.5rem;
        border-top: 1px solid #e5e7eb;
      }

      .experiment-table tbody tr:hover {
        background-color: #eff6ff;
      }

      .weight-input {
        width: 5rem;
        padding: 0.375rem;
        border: 1px solid #93c5fd;
        border-radius: 0.375rem;
        box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
      }

      .weight-input:focus {
        border-color: #3b82f6;
        outline: none;
        box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.5);
      }

      .variation-name {
        font-weight: 500;
        color: #1e3a8a;
      }

      .stat-cell {
        color: #2563eb;
      }

    .form-actions {
        margin-top: 1rem;
        display: flex;
        justify-content: flex-start;
      }

      .save-button {
        background-color: #2563eb;
        color: white;
        padding: 0.625rem 0.875rem;
        border-radius: 0.375rem;
        font-weight: 600;
        font-size: 0.875rem;
        cursor: pointer;
        border: none;
      }

      .save-button:hover {
        background-color: #3b82f6;
      }

      .stat-cell-secondary {
      color: #2563eb;
      background-color: #f8fafc;
      }

      .success-message {
        margin-top: 1rem;
        padding: 1rem;
        background-color: #eff6ff;
        border: 1px solid #bfdbfe;
        color: #1e40af;
        border-radius: 0.375rem;
        display: flex;
        align-items: center;
      }

      .success-icon {
        height: 1.25rem;
        width: 1.25rem;
        color: #60a5fa;
        margin-right: 0.5rem;
      }
    </style>

    <div class="experiment-container">
      <.link patch={"index"} class="back-button">← Back to Experiments</.link>

      <div class="experiment-header">
        <div class="experiment-title-section">
          <h2 class="experiment-title"><%= @experiment.name %></h2>
          <p class="experiment-description"><%= @experiment.description %></p>
        </div>
      </div>

      <div class="experiment-content">
        <form phx-submit="save_weights">
          <div class="table-container">
            <div class="table-wrapper">
              <div class="table-box">
                <table class="experiment-table">
      <thead>
        <tr>
          <th scope="col">Weight</th>
          <th scope="col">Variation</th>
          <th scope="col">Trials</th>
          <th scope="col"><%= @experiment.success1_label || "Success" %></th>
          <th scope="col"><%= @experiment.success1_label || "Success" %> Unique</th>
          <th scope="col"><%= @experiment.success1_label || "Success" %> Amount</th>
          <th scope="col"><%= @experiment.success1_label || "Success" %> Rate</th>
          <%= if show_success2?(@experiment, @summary) do %>
            <th scope="col"><%= @experiment.success2_label %></th>
            <th scope="col"><%= @experiment.success2_label %> Unique</th>
            <th scope="col"><%= @experiment.success2_label %> Amount</th>
            <th scope="col"><%= @experiment.success2_label %> Rate</th>
          <% end %>
        </tr>
      </thead>

      <tbody>
      <%= for {row, {v_id, _name, w}} <- Enum.zip(@summary, @weights_form) do %>
      <tr>
        <td>
          <input type="number"
            name={"weights[weight_#{v_id}]"}
            value={w}
            step="0.01"
            min="0"
            max="1"
            class="weight-input"
          />
        </td>
        <td class="variation-name"><%= row.variation_name %></td>
        <td class="stat-cell"><%= row.trials %></td>
        <td class="stat-cell"><%= row.success1.count %></td>
        <td class="stat-cell"><%= row.success1.unique_count %></td>
        <td class="stat-cell"><%= Float.round(row.success1.amount, 2) %></td>
        <td class="stat-cell"><%= Float.round(row.success1.rate * 100, 2) %>%</td>
        <%= if show_success2?(@experiment, @summary) do %>
          <td class="stat-cell-secondary"><%= row.success2.count %></td>
          <td class="stat-cell-secondary"><%= row.success2.unique_count %></td>
          <td class="stat-cell-secondary"><%= Float.round(row.success2.amount, 2) %></td>
          <td class="stat-cell-secondary"><%= Float.round(row.success2.rate * 100, 2) %>%</td>
        <% end %>
      </tr>
      <% end %>
      </tbody>
    </table>
              </div>
            </div>
          </div>

          <div class="form-actions">
            <button type="submit" class="save-button">
              Save Weights
            </button>
          </div>
        </form>

        <%= if @updated? do %>
          <div class="success-message">
            <svg class="success-icon" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
            </svg>
            Weights updated successfully
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("save_weights", %{"weights" => weights_params}, socket) do
    experiment = socket.assigns.experiment

    Enum.each(weights_params, fn {"weight_" <> var_id_str, weight_str} ->
      var_id = String.to_integer(var_id_str)
      variation = Enum.find(experiment.variations, &(&1.id == var_id))

      weight =
        if String.starts_with?(weight_str, "."),
          do: String.to_float("0" <> weight_str),
          else: String.to_float(weight_str)

      Experiments.update_weight(variation, weight)
    end)

    {:noreply,
     socket
     |> load_experiment(socket.assigns.experiment.id)
     |> assign(:updated?, true)}
  end

  defp load_experiment(socket, id) do
    experiment = Experiments.get_experiment_by_id(id)

    if experiment do
      summary = Experiments.experiment_summary(experiment.name)

      socket
      |> assign(:experiment, experiment)
      |> assign(:summary, summary)
      |> assign(:updated?, false)
      |> assign(:weights_form, build_weights_form(experiment.variations))
    else
      socket
    end
  end

  defp show_success2?(experiment, summary) do
    has_label = experiment.success2_label && experiment.success2_label != ""
    has_conversions = Enum.any?(summary, fn row -> row.success2.count > 0 end)
    has_label || has_conversions
  end

  defp build_weights_form(variations) do
    for v <- variations, do: {v.id, v.name, v.weight}
  end
end
