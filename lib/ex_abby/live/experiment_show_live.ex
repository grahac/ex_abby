defmodule ExAbby.Live.ExperimentShowLive do
  @moduledoc """
  Shows a single experiment's variations, plus editing of weights.
  """
  alias ExAbby.{Experiments, Statistics}
  use Phoenix.LiveView

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

    .p-value-significant {
      color: #047857;
      font-weight: bold;
    }

    .p-value-unavailable {
      color: #64748b;
      font-size: 0.875rem;
    }

    .p-value-detail {
      display: flex;
      flex-direction: column;
      align-items: flex-start;
      gap: 2px;
      margin-top: 4px;
      color: #64748b;
      font-size: 0.75rem;
      font-weight: normal;
      white-space: nowrap;
    }

    .sig-chart {
      flex: none;
    }

    .sig-chart-zero {
      stroke: #cbd5e1;
      stroke-width: 1;
    }

    .sig-chart-range {
      stroke: #94a3b8;
      stroke-width: 2;
      stroke-linecap: round;
    }

    .sig-chart-point {
      fill: #64748b;
    }

    .sig-chart-significant .sig-chart-range {
      stroke: #047857;
    }

    .sig-chart-significant .sig-chart-point {
      fill: #047857;
    }

    .significance-note {
      margin-top: 12px;
      color: #475569;
      font-size: 0.875rem;
    }

    .significance-warning {
      margin-top: 12px;
      padding: 12px;
      background-color: #fef3c7;
      border: 1px solid #f59e0b;
      border-radius: 4px;
      color: #92400e;
      font-size: 0.875rem;
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
              <th>Excluded</th>
              <th><%= @experiment.success1_label || "Success" %></th>
              <th><%= @experiment.success1_label || "Success" %> Unique</th>
              <th><%= @experiment.success1_label || "Success" %> Amount</th>
              <th><%= @experiment.success1_label || "Success" %> Rate</th>
              <th>P vs <%= @control_variation_name %></th>
              <%= if show_success2?(@experiment, @summary) do %>
                <th><%= @experiment.success2_label %></th>
                <th><%= @experiment.success2_label %> Unique</th>
                <th><%= @experiment.success2_label %> Amount</th>
                <th><%= @experiment.success2_label %> Rate</th>
                <th>P vs <%= @control_variation_name %></th>
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
                <td><%= row.excluded_trials %></td>
                <td><%= row.success1.count %></td>
                <td><%= row.success1.unique_count %></td>
                <td><%= Float.round(row.success1.amount, 2) %></td>
                <td><%= Float.round(row.success1.rate * 100, 2) %>%</td>
                <.significance_td
                  significance={@success1_significance}
                  variation_id={row.variation_id}
                  scale={@success1_scale}
                />
                <%= if show_success2?(@experiment, @summary) do %>
                  <td><%= row.success2.count %></td>
                  <td><%= row.success2.unique_count %></td>
                  <td><%= Float.round(row.success2.amount, 2) %></td>
                  <td><%= Float.round(row.success2.rate * 100, 2) %>%</td>
                  <.significance_td
                    significance={@success2_significance}
                    variation_id={row.variation_id}
                    scale={@success2_scale}
                  />
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>

        <%= unless @experiment.archived_at do %>
          <button type="submit" class="save-button">Save Weights</button>
        <% end %>
      </form>

      <%= case @success1_significance do %>
        <% {:ok, _significance} -> %>
          <p class="significance-note">
            Anytime-valid p-values compare each treatment with
            <strong><%= @control_variation_name %></strong> using unique conversions in the
            selected date range. They remain valid during continuous monitoring when the start
            date and metrics are fixed independently of the results. P-values are Holm-adjusted
            together across every configured treatment arm and displayed success metric,
            including any arm with no data yet. Either success metric can be highlighted; both
            do not need to be significant.
          </p>
          <p class="significance-note">
            The chart plots the measured lift (dot) and its 95% anytime-valid interval (bar)
            against a zero line. Values are the <strong>difference between the two conversion
            rates in points</strong>, not a relative change: a control at 20% against a treatment
            at 30% shows as +10%, not +50%. Negative means the treatment converted worse than
            control. A bar that crosses the zero line means the data cannot
            yet rule out "no difference". Intervals are <em>not</em> Holm-adjusted, so with
            several treatments a bar can clear zero while the adjusted p-value is above 0.05.
            "No data" means either arm has no eligible trials.
          </p>
        <% {:error, :control_not_found} -> %>
          <p class="significance-warning">
            Significance is unavailable because this experiment has no variation named
            <strong><%= @control_variation_name %></strong>.
          </p>
      <% end %>

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

      control_variation_name =
        Application.get_env(:ex_abby, :control_variation_name, "control")

      show_success2 = show_success2?(experiment, summary)
      metrics = if show_success2, do: [:success1, :success2], else: [:success1]

      {success1_significance, success2_significance} =
        case Statistics.compare_metrics_to_control(summary, metrics,
               control_name: control_variation_name
             ) do
          {:ok, significance_by_metric} ->
            success1 = {:ok, Map.fetch!(significance_by_metric, :success1)}

            success2 =
              if show_success2 do
                {:ok, Map.fetch!(significance_by_metric, :success2)}
              end

            {success1, success2}

          {:error, _reason} = error ->
            {error, if(show_success2, do: error)}
        end

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
      |> assign(:control_variation_name, control_variation_name)
      |> assign(:success1_significance, success1_significance)
      |> assign(:success2_significance, success2_significance)
      |> assign(:success1_scale, significance_scale(success1_significance))
      |> assign(:success2_scale, significance_scale(success2_significance))
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

  # One dispatch for the whole cell: which arm this row is, and what to draw.
  defp significance_cell({:error, :control_not_found}, _variation_id),
    do: %{kind: :unavailable, class: "p-value-unavailable", label: "—"}

  defp significance_cell(
         {:ok, %{control_variation_id: control_variation_id}},
         control_variation_id
       ),
       do: %{kind: :control, class: nil, label: "Control"}

  defp significance_cell({:ok, %{comparisons: comparisons}}, variation_id) do
    case Map.fetch!(comparisons, variation_id) do
      %{status: :insufficient_data} ->
        %{kind: :no_data, class: "p-value-unavailable", label: "No data"}

      %{p_value: p_value, significant?: significant?, lift: lift, confidence_interval: interval} ->
        %{
          kind: :comparison,
          class: if(significant?, do: "p-value-significant"),
          label: format_p_value(p_value),
          significant?: significant?,
          lift: lift,
          lower: interval.lower,
          upper: interval.upper
        }
    end
  end

  defp format_p_value(p_value) when p_value < 0.001, do: "< 0.001"
  defp format_p_value(p_value), do: :erlang.float_to_binary(p_value, decimals: 3)

  # A shared horizontal scale for every row in a column, so the bars are
  # comparable with each other and still use the width once intervals tighten.
  @scale_steps [1.0, 2.0, 5.0, 10.0, 25.0, 50.0, 100.0]

  defp significance_scale({:ok, %{comparisons: comparisons}}) do
    bounds =
      comparisons
      |> Map.values()
      |> Enum.filter(&Map.has_key?(&1, :confidence_interval))
      |> Enum.map(fn %{confidence_interval: interval} ->
        max(abs(interval.lower), abs(interval.upper)) * 100
      end)

    case bounds do
      [] -> nil
      bounds -> Enum.find(@scale_steps, 100.0, &(&1 >= Enum.max(bounds)))
    end
  end

  defp significance_scale(_significance), do: nil

  attr(:significance, :any, required: true)
  attr(:variation_id, :integer, required: true)
  attr(:scale, :any, required: true)

  defp significance_td(assigns) do
    assigns =
      assign(assigns, :cell, significance_cell(assigns.significance, assigns.variation_id))

    ~H"""
    <td class={@cell.class}>
      <span>{@cell.label}</span>
      <%= if @cell.kind == :comparison do %>
        <small class="p-value-detail">
          <svg
            class={["sig-chart", @cell.significant? && "sig-chart-significant"]}
            width="120"
            height="16"
            viewBox="0 0 120 16"
            role="img"
          >
            <title>{chart_title(@cell)}</title>
            <line
              class="sig-chart-zero"
              x1={chart_x(0.0, @scale)}
              y1="1"
              x2={chart_x(0.0, @scale)}
              y2="15"
            />
            <line
              class="sig-chart-range"
              x1={chart_x(@cell.lower, @scale)}
              y1="8"
              x2={chart_x(@cell.upper, @scale)}
              y2="8"
            />
            <circle class="sig-chart-point" cx={chart_x(@cell.lift, @scale)} cy="8" r="3" />
          </svg>
          <span>
            {format_percent(@cell.lift)} [{format_percent(@cell.lower)}, {format_percent(@cell.upper)}]
          </span>
        </small>
      <% end %>
    </td>
    """
  end

  defp chart_x(proportion, scale) do
    points = max(-scale, min(scale, proportion * 100))
    Float.round(60.0 + points / scale * 58.0, 2)
  end

  defp chart_title(cell) do
    "Lift #{format_percent(cell.lift)}; 95% interval " <>
      "#{format_percent(cell.lower)} to #{format_percent(cell.upper)}"
  end

  defp format_percent(proportion) do
    value = Float.round(proportion * 100, 1)
    formatted = :erlang.float_to_binary(value, decimals: 1)

    cond do
      value > 0.0 -> "+" <> formatted <> "%"
      value == 0.0 -> "0.0%"
      true -> formatted <> "%"
    end
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
