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
    <ExAbby.Live.AdminStyle.styles />
    <style>
      .ex-abby-admin .ex-abby-show__back {
        margin-bottom: 1.5rem;
      }

      .ex-abby-admin .ex-abby-show__header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        gap: 2rem;
        margin-bottom: 2rem;
      }

      .ex-abby-admin .date-filter {
        flex: none;
        padding: 1rem;
      }

      .ex-abby-admin .date-filter form {
        display: flex;
        gap: 0.75rem;
        align-items: flex-end;
      }

      .ex-abby-admin .date-filter input {
        width: 12.5rem;
      }

      .ex-abby-admin .weight-input {
        width: 4rem;
      }

      /* Let the many-column results table pack tighter: allow long header
         labels to wrap onto multiple rows and shrink the header type so each
         column sizes to its widest word rather than the whole phrase. */
      .ex-abby-admin .ex-abby-table th {
        font-size: 0.625rem;
        white-space: normal;
        vertical-align: bottom;
        line-height: 1.25;
      }

      .ex-abby-admin .save-button {
        margin-top: 1rem;
      }

      .ex-abby-admin .success-message {
        display: flex;
        align-items: center;
        margin-top: 1rem;
        padding: 0.875rem 1rem;
        background: var(--ex-abby-color-success-surface);
        border: 1px solid var(--ex-abby-color-success);
        border-radius: 4px;
        color: var(--ex-abby-color-success);
        font-size: 0.875rem;
        font-weight: 600;
      }

      .ex-abby-admin .date-filter .error-message {
        margin-top: 0.75rem;
        padding: 0.75rem 1rem;
        background: var(--ex-abby-color-danger-surface);
        border: 1px solid var(--ex-abby-color-danger);
        border-radius: 4px;
        color: var(--ex-abby-color-danger);
        font-size: 0.875rem;
      }

      .ex-abby-admin .archive-section {
        margin-top: 1.5rem;
      }

      .ex-abby-admin .archived-banner,
      .ex-abby-admin .archive-form {
        display: flex;
        align-items: center;
        gap: 1rem;
        padding: 1rem;
      }

      .ex-abby-admin .archived-banner {
        background: var(--ex-abby-color-warning-surface);
        border-color: var(--ex-abby-color-warning);
        color: var(--ex-abby-color-warning);
      }

      .ex-abby-admin .archived-label {
        font-size: 0.75rem;
        font-weight: 700;
        letter-spacing: 0.06em;
        text-transform: uppercase;
      }

      .ex-abby-admin .unarchive-button {
        margin-left: auto;
      }

      .ex-abby-admin .archive-form label {
        color: var(--ex-abby-color-ink-soft);
        font-size: 0.875rem;
        font-weight: 500;
      }

      .ex-abby-admin .weight-input:disabled {
        background: var(--ex-abby-color-canvas);
        color: var(--ex-abby-color-ink-soft);
        cursor: not-allowed;
      }

      .ex-abby-admin .p-value-significant {
        color: var(--ex-abby-color-success);
        font-weight: 700;
      }

      .ex-abby-admin .p-value-unavailable,
      .ex-abby-admin .p-value-detail {
        color: var(--ex-abby-color-ink-soft);
      }

      .ex-abby-admin .p-value-unavailable {
        font-size: 0.875rem;
      }

      .ex-abby-admin .p-value-detail {
        display: flex;
        flex-direction: column;
        align-items: flex-start;
        gap: 2px;
        margin-top: 4px;
        font-size: 0.75rem;
        font-weight: 400;
        white-space: nowrap;
      }

      .ex-abby-admin .sig-chart {
        flex: none;
      }

      .ex-abby-admin .sig-chart-zero {
        stroke: var(--ex-abby-color-border-strong);
        stroke-width: 1;
      }

      .ex-abby-admin .sig-chart-range {
        stroke: var(--ex-abby-color-warm-slate);
        stroke-width: 2;
        stroke-linecap: round;
      }

      .ex-abby-admin .sig-chart-point {
        fill: var(--ex-abby-color-warm-slate);
      }

      .ex-abby-admin .sig-chart-significant .sig-chart-range {
        stroke: var(--ex-abby-color-success);
      }

      .ex-abby-admin .sig-chart-significant .sig-chart-point {
        fill: var(--ex-abby-color-success);
      }

      .ex-abby-admin .significance-note {
        max-width: 60rem;
        margin: 0.75rem 0 0;
        color: var(--ex-abby-color-ink-soft);
        font-size: 0.875rem;
        line-height: 1.6;
      }

      .ex-abby-admin .significance-warning {
        margin-top: 0.75rem;
        padding: 0.875rem 1rem;
        background: var(--ex-abby-color-warning-surface);
        border: 1px solid var(--ex-abby-color-warning);
        border-radius: 4px;
        color: var(--ex-abby-color-warning);
        font-size: 0.875rem;
      }

      @media (max-width: 960px) {
        .ex-abby-admin .ex-abby-show__header,
        .ex-abby-admin .date-filter form {
          flex-direction: column;
        }

        .ex-abby-admin .date-filter {
          width: 100%;
        }

        .ex-abby-admin .date-filter form {
          align-items: stretch;
        }

        .ex-abby-admin .date-filter input {
          width: 100%;
        }
      }
    </style>

    <div class="ex-abby-admin">
      <main class="ex-abby-admin__shell">
        <.link
          patch={"index"}
          class="ex-abby-button ex-abby-button--secondary ex-abby-show__back"
        >
          ← Back to Experiments
        </.link>

        <header class="ex-abby-show__header">
          <div>
            <h1 class="ex-abby-admin__title"><%= @experiment.name %></h1>
            <p class="ex-abby-admin__subtitle"><%= @experiment.description %></p>
          </div>

          <div class="date-filter ex-abby-panel">
            <form phx-submit="update_date_range">
              <div>
                <label for="ex-abby-start-time" class="ex-abby-label">From</label>
                <input
                  id="ex-abby-start-time"
                  class="ex-abby-input"
                  type="text"
                  name="start_time"
                  value={@start_time}
                  placeholder="e.g., 7 days ago"
                />
              </div>
              <div>
                <label for="ex-abby-end-time" class="ex-abby-label">To</label>
                <input
                  id="ex-abby-end-time"
                  class="ex-abby-input"
                  type="text"
                  name="end_time"
                  value={@end_time}
                  placeholder="e.g., now"
                />
              </div>
              <button type="submit" class="ex-abby-button ex-abby-button--primary">
                Update Range
              </button>
            </form>
            <%= if @from_to_error_message do %>
              <div class="error-message">
                <%= @from_to_error_message %>
              </div>
            <% end %>
          </div>
        </header>

        <form phx-submit="save_weights">
          <div class="ex-abby-table-frame">
            <table class="ex-abby-table">
              <thead>
                <tr>
                  <th>Weight</th>
                  <th>Variation</th>
                  <th>Trials</th>
                  <th>{@experiment.success1_label || "Success"}<br />(Unique)</th>
                  <th>{@experiment.success1_label || "Success"}<br />Amount</th>
                  <th>{@experiment.success1_label || "Success"}<br />Rate</th>
                  <th>P vs <%= @control_variation_name %></th>
                  <%= if show_success2?(@experiment, @summary) do %>
                    <th>{@experiment.success2_label}<br />(Unique)</th>
                    <th>{@experiment.success2_label}<br />Amount</th>
                    <th>{@experiment.success2_label}<br />Rate</th>
                    <th>P vs <%= @control_variation_name %></th>
                  <% end %>
                </tr>
              </thead>

              <tbody>
                <%= for {row, {v_id, _name, w}} <- Enum.zip(@summary, @weights_form) do %>
                  <tr>
                    <td>
                      <input
                        type="number"
                        name={"weights[weight_#{v_id}]"}
                        value={w}
                        step="0.01"
                        min="0"
                        max="1"
                        class="ex-abby-input weight-input"
                        disabled={not is_nil(@experiment.archived_at)}
                      />
                    </td>
                    <td><%= row.variation_name %></td>
                    <td><%= row.trials %></td>
                    <td><%= row.success1.count %> (<%= row.success1.unique_count %>)</td>
                    <td><%= Float.round(row.success1.amount, 2) %></td>
                    <td><%= Float.round(row.success1.rate * 100, 2) %>%</td>
                    <.significance_td
                      significance={@success1_significance}
                      variation_id={row.variation_id}
                      scale={@success1_scale}
                    />
                    <%= if show_success2?(@experiment, @summary) do %>
                      <td><%= row.success2.count %> (<%= row.success2.unique_count %>)</td>
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
          </div>

          <%= unless @experiment.archived_at do %>
            <button
              type="submit"
              class="ex-abby-button ex-abby-button--primary save-button"
            >
              Save Weights
            </button>
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

        <div class="archive-section">
          <%= if @experiment.archived_at do %>
            <div class="archived-banner ex-abby-panel">
              <span class="archived-label">Archived</span>
              <%= if @winner_variation do %>
                <span>Winner: <strong>{@winner_variation.name}</strong></span>
              <% end %>
              <button
                phx-click="unarchive"
                class="ex-abby-button ex-abby-button--secondary unarchive-button"
              >
                Unarchive
              </button>
            </div>
          <% else %>
            <form phx-submit="archive" class="archive-form ex-abby-panel">
              <label>Archive with winner (optional):</label>
              <select name="winner_variation_id" class="ex-abby-select">
                <option value="">No winner</option>
                <%= for v <- @experiment.variations do %>
                  <option value={v.id}>{v.name}</option>
                <% end %>
              </select>
              <button type="submit" class="ex-abby-button ex-abby-button--danger">
                Archive Experiment
              </button>
            </form>
          <% end %>
        </div>
      </main>
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
