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
      {:ok,
       socket
       |> assign(:page_title, "ExAbby - #{socket.assigns.experiment.name}")
       |> assign(:start_time, socket.assigns.experiment.start_time)
       |> assign(:end_time, socket.assigns.experiment.end_time)
       # Add this line
       |> assign(:from_to_error_message, nil)}
    else
      {:ok, push_navigate(socket, to: "/")}
    end
  end

  def render(assigns) do
    ~H"""
    <style>
      .container {
        max-width: 1280px;
        margin: 0 auto;
        padding: 20px;
      }

      .back-button {
        display: inline-block;
        padding: 8px 16px;
        background-color: #93c5fd;
        color: #1e3a8a;
        text-decoration: none;
        border-radius: 4px;
        margin-bottom: 16px;
      }

      .header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        margin-bottom: 32px;
      }

      .title-section h2 {
        font-size: 24px;
        font-weight: bold;
        color: #1e3a8a;
        margin: 0;
      }

      .title-section p {
        margin-top: 8px;
        color: #2563eb;
      }

      .date-filter {
        background: #f8fafc;
        padding: 16px;
        border-radius: 4px;
        border: 1px solid #e2e8f0;
      }

      .date-filter form {
        display: flex;
        gap: 16px;
        align-items: flex-end;
      }

      .date-filter label {
        display: block;
        font-size: 14px;
        margin-bottom: 4px;
        color: #475569;
      }

      .date-filter input {
        padding: 6px 12px;
        border: 1px solid #cbd5e1;
        border-radius: 4px;
        width: 200px;
      }

      .date-filter button {
        padding: 8px 16px;
        background-color: #2563eb;
        color: white;
        border: none;
        border-radius: 4px;
        cursor: pointer;
      }

      .date-filter button:hover {
        background-color: #1d4ed8;
      }

      table {
        width: 100%;
        border-collapse: collapse;
        margin-top: 16px;
      }

      th {
        background-color: #eff6ff;
        padding: 12px;
        text-align: left;
        font-size: 12px;
        color: #1d4ed8;
        text-transform: uppercase;
      }

      td {
        padding: 12px;
        border-top: 1px solid #e5e7eb;
      }

      tr:hover {
        background-color: #f8fafc;
      }

      .weight-input {
        width: 80px;
        padding: 6px;
        border: 1px solid #93c5fd;
        border-radius: 4px;
      }

      .save-button {
        margin-top: 16px;
        padding: 8px 16px;
        background-color: #2563eb;
        color: white;
        border: none;
        border-radius: 4px;
        cursor: pointer;
      }

      .success-message {
        margin-top: 16px;
        padding: 16px;
        background-color: #eff6ff;
        border: 1px solid #bfdbfe;
        color: #1e40af;
        border-radius: 4px;
        display: flex;
        align-items: center;
      }
    .date-filter .error-message {
    margin-top: 12px;
    background-color: #fde8e8;
    border: 1px solid #f98080;
    color: #c81e1e;
    padding: 0.75rem 1rem;
    border-radius: 0.25rem;
    font-size: 14px;
    }

    .archive-section {
      margin-bottom: 1.5rem;
    }

    .archived-banner {
      display: flex;
      align-items: center;
      gap: 1rem;
      padding: 1rem;
      background-color: #fef3c7;
      border: 1px solid #f59e0b;
      border-radius: 4px;
    }

    .archived-label {
      font-weight: bold;
      color: #b45309;
      text-transform: uppercase;
    }

    .unarchive-button {
      margin-left: auto;
      padding: 0.5rem 1rem;
      background-color: #059669;
      color: white;
      border: none;
      border-radius: 4px;
      cursor: pointer;
    }

    .unarchive-button:hover {
      background-color: #047857;
    }

    .archive-form {
      display: flex;
      align-items: center;
      gap: 1rem;
      padding: 1rem;
      background-color: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 4px;
    }

    .archive-form select {
      padding: 0.5rem;
      border: 1px solid #cbd5e1;
      border-radius: 4px;
    }

    .archive-button {
      padding: 0.5rem 1rem;
      background-color: #dc2626;
      color: white;
      border: none;
      border-radius: 4px;
      cursor: pointer;
    }

    .archive-button:hover {
      background-color: #b91c1c;
    }

    .weight-input:disabled {
      background-color: #f3f4f6;
      cursor: not-allowed;
    }
    </style>

    <div class="container">
      <.link patch={"index"} class="back-button">← Back to Experiments</.link>

      <div class="header">
        <div class="title-section">
          <h2><%= @experiment.name %></h2>
          <p><%= @experiment.description %></p>
        </div>

        <div class="date-filter">
          <form phx-submit="update_date_range">
            <div>
              <label>From</label>
              <input type="text" name="start_time" value={@start_time} placeholder="e.g., 7 days ago or 11/15/2025 3PM" />
            </div>
            <div>
              <label>To</label>
              <input type="text" name="end_time" value={@end_time} placeholder="e.g., now or 11/15/2025 3PM" />
            </div>
            <button type="submit">Update Range</button>
          </form>
          <%= if @from_to_error_message do %>
            <div class="error-message">
              <%= @from_to_error_message %>
            </div>
          <% end %>
        </div>
    </div>

      <div class="archive-section">
        <%= if @experiment.archived_at do %>
          <div class="archived-banner">
            <span class="archived-label">Archived</span>
            <%= if @winner_variation do %>
              <span>Winner: <strong>{@winner_variation.name}</strong></span>
            <% end %>
            <button phx-click="unarchive" class="unarchive-button">Unarchive</button>
          </div>
        <% else %>
          <form phx-submit="archive" class="archive-form">
            <label>Archive with winner (optional):</label>
            <select name="winner_variation_id">
              <option value="">No winner</option>
              <%= for v <- @experiment.variations do %>
                <option value={v.id}>{v.name}</option>
              <% end %>
            </select>
            <button type="submit" class="archive-button">Archive Experiment</button>
          </form>
        <% end %>
      </div>

      <form phx-submit="save_weights">
        <table>
          <thead>
            <tr>
              <th>Weight</th>
              <th>Variation</th>
              <th>Trials</th>
              <th><%= @experiment.success1_label || "Success" %></th>
              <th><%= @experiment.success1_label || "Success" %> Unique</th>
              <th><%= @experiment.success1_label || "Success" %> Amount</th>
              <th><%= @experiment.success1_label || "Success" %> Rate</th>
              <%= if show_success2?(@experiment, @summary) do %>
                <th><%= @experiment.success2_label %></th>
                <th><%= @experiment.success2_label %> Unique</th>
                <th><%= @experiment.success2_label %> Amount</th>
                <th><%= @experiment.success2_label %> Rate</th>
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
                    disabled={not is_nil(@experiment.archived_at)}
                  />
                </td>
                <td><%= row.variation_name %></td>
                <td><%= row.trials %></td>
                <td><%= row.success1.count %></td>
                <td><%= row.success1.unique_count %></td>
                <td><%= Float.round(row.success1.amount, 2) %></td>
                <td><%= Float.round(row.success1.rate * 100, 2) %>%</td>
                <%= if show_success2?(@experiment, @summary) do %>
                  <td><%= row.success2.count %></td>
                  <td><%= row.success2.unique_count %></td>
                  <td><%= Float.round(row.success2.amount, 2) %></td>
                  <td><%= Float.round(row.success2.rate * 100, 2) %>%</td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>

        <%= unless @experiment.archived_at do %>
          <button type="submit" class="save-button">Save Weights</button>
        <% end %>
      </form>

      <%= if @updated? do %>
        <div class="success-message">
          Weights updated successfully
        </div>
      <% end %>



    </div>
    """
  end

  def handle_event(
        "update_date_range",
        %{"start_time" => start_time, "end_time" => end_time},
        socket
      ) do
    with {:ok, _parsed_start} <- validate_datetime(start_time, "from"),
         {:ok, _parsed_end} <- validate_datetime(end_time, "to") do
      {:ok, updated_experiment} =
        Experiments.update_experiment(socket.assigns.experiment, %{
          start_time: start_time,
          end_time: end_time
        })

      {:noreply,
       socket
       |> assign(:experiment, updated_experiment)
       |> assign(:start_time, start_time)
       |> assign(:end_time, end_time)
       |> load_experiment(updated_experiment.id)}
    else
      {:error, message} ->
        Process.send_after(self(), :clear_error, 5000)
        {:noreply, assign(socket, :from_to_error_message, message)}
    end
  end

  def handle_event("save_weights", %{"weights" => weights_params}, socket) do
    experiment = socket.assigns.experiment

    now = DateTime.utc_now()
    formatted_time = Calendar.strftime(now, "%m/%d/%Y %I:%M%p UTC")

    {:ok, _updated_experiment} =
      Experiments.update_experiment(experiment, %{start_time: formatted_time})

    Enum.each(weights_params, fn {"weight_" <> var_id_str, weight_str} ->
      var_id = String.to_integer(var_id_str)
      variation = Enum.find(experiment.variations, &(&1.id == var_id))

      weight =
        cond do
          weight_str == "0" -> 0.0
          String.starts_with?(weight_str, ".") -> String.to_float("0" <> weight_str)
          true -> String.to_float(weight_str)
        end

      Experiments.update_weight(variation, weight)
    end)

    {:noreply,
     socket
     |> load_experiment(socket.assigns.experiment.id)
     |> assign(:start_time, formatted_time)
     |> assign(:updated?, true)}
  end

  def handle_event("archive", %{"winner_variation_id" => winner_id}, socket) do
    winner_variation_id = if winner_id == "", do: nil, else: String.to_integer(winner_id)

    {:ok, _} = Experiments.archive_experiment(socket.assigns.experiment.id, winner_variation_id)

    {:noreply, load_experiment(socket, socket.assigns.experiment.id)}
  end

  def handle_event("unarchive", _params, socket) do
    {:ok, _} = Experiments.unarchive_experiment(socket.assigns.experiment.id)

    {:noreply, load_experiment(socket, socket.assigns.experiment.id)}
  end

  def handle_info(:clear_error, socket) do
    {:noreply, assign(socket, :from_to_error_message, nil)}
  end

  defp load_experiment(socket, id) do
    experiment = Experiments.get_experiment_by_id(id)

    if experiment do
      summary = Experiments.experiment_summary(experiment.name)

      winner_variation =
        if experiment.winner_variation_id do
          Experiments.get_variation(experiment.winner_variation_id)
        else
          nil
        end

      socket
      |> assign(:experiment, experiment)
      |> assign(:summary, summary)
      |> assign(:updated?, false)
      |> assign(:weights_form, build_weights_form(experiment.variations))
      |> assign(:winner_variation, winner_variation)
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

  defp validate_datetime(nil, _field), do: {:ok, nil}
  defp validate_datetime("", _field), do: {:ok, nil}

  defp validate_datetime(datetime_str, field) do
    case ExAbby.DatetimeParser.parse(datetime_str) do
      {:ok, _datetime} -> {:ok, datetime_str}
      nil -> {:error, "Invalid datetime field for '#{field}' field "}
    end
  end
end
