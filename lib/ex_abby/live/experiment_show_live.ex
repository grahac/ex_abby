defmodule ExAbby.Live.ExperimentShowLive do
  @moduledoc """
  Shows a single experiment's variations, plus editing of weights.
  """
  alias ExAbby.{Experiments, ExperimentReport}
  use Phoenix.LiveView
  import ExAbby.Live.AdminComponents

  def mount(%{"id" => id}, _session, socket) do
    socket = load_experiment(socket, String.to_integer(id))

    if(socket.assigns[:experiment]) do
      {:ok,
       socket
       |> assign(:page_title, "ExAbby - #{socket.assigns.experiment.name}")
       |> assign(:start_time, socket.assigns.experiment.start_time)
       |> assign(:end_time, socket.assigns.experiment.end_time)
       |> assign(:from_to_error_message, nil)}
    else
      {:ok, push_navigate(socket, to: "/")}
    end
  end

  def render(assigns) do
    ~H"""
    <ExAbby.Live.AdminStyle.styles />
    <style>
      .ex-abby-admin .ex-abby-show__title-row {
        display: flex;
        align-items: center;
        gap: 0.75rem;
        margin-bottom: 0.625rem;
      }

      .ex-abby-admin .ex-abby-show__title-block {
        max-width: 36rem;
      }

      .ex-abby-admin .ex-abby-show__date-panel {
        flex: none;
      }

      .ex-abby-admin .ex-abby-show__date-fields {
        display: flex;
        align-items: flex-end;
        gap: 0.625rem;
        flex-wrap: wrap;
      }

      .ex-abby-admin .ex-abby-show__date-input {
        width: 11.25rem;
      }

      .ex-abby-admin .ex-abby-show__date-error {
        margin-top: 0.75rem;
        padding: 0.75rem 1rem;
        background: var(--ex-abby-color-danger-surface);
        border: 1px solid var(--ex-abby-color-danger);
        border-radius: 6px;
        color: var(--ex-abby-color-danger);
        font-size: 0.8125rem;
      }

      .ex-abby-admin .ex-abby-show__block {
        margin-top: 1.5rem;
      }

      .ex-abby-admin .ex-abby-summary {
        margin-top: 1.75rem;
        background: var(--ex-abby-color-surface);
        border: 1px solid var(--ex-abby-color-border);
        border-radius: 10px;
        overflow-x: auto;
      }

      .ex-abby-admin .ex-abby-summary__row {
        display: flex;
        min-width: 56.25rem;
      }

      .ex-abby-admin .ex-abby-summary__headline {
        flex: 1 1 auto;
        padding: 1.125rem 1.375rem;
        border-left: 3px solid var(--ex-abby-color-accent);
        font-size: 0.9375rem;
        line-height: 1.45;
        text-wrap: pretty;
      }

      .ex-abby-admin .ex-abby-summary__headline--warning {
        border-left-color: var(--ex-abby-color-warning-accent);
      }

      .ex-abby-admin .ex-abby-summary__stats {
        display: flex;
        border-left: 1px solid var(--ex-abby-color-border-soft);
      }

      .ex-abby-admin .ex-abby-summary__stat {
        padding: 1rem 1.375rem;
        text-align: right;
        min-width: 6.875rem;
        border-left: 1px solid var(--ex-abby-color-border-soft);
      }

      .ex-abby-admin .ex-abby-summary__stat:first-child {
        border-left: none;
      }

      .ex-abby-admin .ex-abby-summary__stat-value {
        margin-top: 0.375rem;
        font-family: var(--ex-abby-font-mono);
        font-size: 1.1875rem;
        font-weight: 500;
      }

      .ex-abby-admin .ex-abby-summary__stat-value--significant {
        color: var(--ex-abby-color-accent-deep);
        font-weight: 600;
      }

      .ex-abby-admin .ex-abby-show__table-scroll {
        overflow-x: auto;
      }

      .ex-abby-admin .ex-abby-show__weight-input {
        width: 4.5rem;
        text-align: right;
      }

      .ex-abby-admin .ex-abby-show__variation {
        font-family: var(--ex-abby-font-mono);
        font-size: 0.875rem;
        font-weight: 500;
      }

      .ex-abby-admin .ex-abby-show__variation--leader {
        font-weight: 700;
      }

      .ex-abby-admin .ex-abby-table td.ex-abby-show__rate {
        font-size: 0.9375rem;
        font-weight: 600;
      }

      .ex-abby-admin .ex-abby-show__lift-cell {
        text-align: right;
        font-size: 0.75rem;
      }

      .ex-abby-admin .ex-abby-show__footer-left {
        display: flex;
        align-items: center;
        gap: 0.75rem;
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

      .ex-abby-admin .ex-abby-show__methodology {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 1.25rem;
        margin-top: 1.5rem;
      }

      .ex-abby-admin .ex-abby-show__methodology-panel {
        padding: 1.25rem 1.375rem;
      }

      .ex-abby-admin .ex-abby-show__methodology-panel .ex-abby-eyebrow {
        margin-bottom: 0.625rem;
      }

      .ex-abby-admin .ex-abby-show__methodology-panel p {
        margin: 0;
        color: var(--ex-abby-color-ink-soft);
        font-size: 0.8125rem;
        line-height: 1.6;
        text-wrap: pretty;
      }

      .ex-abby-admin .ex-abby-show__archive-row {
        display: flex;
        align-items: center;
        gap: 0.875rem;
        padding: 1rem 1.25rem;
      }

      .ex-abby-admin .ex-abby-show__archive-title {
        font-size: 0.8125rem;
        font-weight: 600;
      }

      .ex-abby-admin .ex-abby-show__archive-hint {
        font-size: 0.8125rem;
        color: var(--ex-abby-color-ink-muted);
      }

      .ex-abby-admin .ex-abby-show__push-right {
        margin-left: auto;
      }

      @media (max-width: 760px) {
        .ex-abby-admin .ex-abby-show__methodology {
          grid-template-columns: 1fr;
        }

        .ex-abby-admin .ex-abby-show__date-input {
          width: 100%;
        }
      }
    </style>

    <div class="ex-abby-admin">
      <.topbar>
        <:crumbs>
          <.link navigate="index">← Experiments</.link>
          <span class="ex-abby-topbar__separator">/</span>
          <span class="ex-abby-topbar__current">{@experiment.name}</span>
        </:crumbs>
        <:actions>
          <.link navigate="trials" class="ex-abby-topbar__link">Edit trials for session</.link>
          <a
            :if={!archived?(@report)}
            href="#ex-abby-archive"
            class="ex-abby-button ex-abby-button--secondary"
          >
            Archive…
          </a>
        </:actions>
      </.topbar>

      <main class="ex-abby-admin__shell">
        <header class="ex-abby-admin__header">
          <div class="ex-abby-show__title-block">
            <div class="ex-abby-show__title-row">
              <h1 class="ex-abby-admin__title ex-abby-mono">{@experiment.name}</h1>
              <.status_pill experiment={@experiment} />
            </div>
            <p class="ex-abby-admin__subtitle">{@experiment.description}</p>
          </div>

          <div class="ex-abby-show__date-panel">
            <form phx-submit="update_date_range" class="ex-abby-show__date-fields">
              <div>
                <label for="ex-abby-start-time" class="ex-abby-label">From</label>
                <input
                  id="ex-abby-start-time"
                  class="ex-abby-input ex-abby-show__date-input"
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
                  class="ex-abby-input ex-abby-show__date-input"
                  type="text"
                  name="end_time"
                  value={@end_time}
                  placeholder="e.g., now"
                />
              </div>
              <button type="submit" class="ex-abby-button ex-abby-button--primary">
                Update range
              </button>
            </form>
            <div :if={@from_to_error_message} class="ex-abby-show__date-error">
              {@from_to_error_message}
            </div>
          </div>
        </header>

        <.summary_strip report={@report} />

        <.allocation_table report={@report} />
        <div :if={@updated?} class="success-message">Weights updated successfully</div>

        <.metric_panel :for={metric <- @report.metrics} report={@report} metric={metric} />

        <div class="ex-abby-show__methodology">
          <div class="ex-abby-panel ex-abby-show__methodology-panel">
            <span class="ex-abby-eyebrow">How the p-values work</span>
            <p>
              Anytime-valid p-values compare each treatment with
              <span class="ex-abby-mono">{@report.control_variation_name}</span>
              using unique conversions in the selected date range. They stay valid under
              continuous monitoring as long as the start date and metrics were fixed
              independently of the results. P-values are Holm-adjusted across every treatment
              arm and displayed metric, including arms with no data yet. Either metric can be
              significant on its own.
            </p>
          </div>
          <div class="ex-abby-panel ex-abby-show__methodology-panel">
            <span class="ex-abby-eyebrow">How to read the lift bar</span>
            <p>
              In the allocation table, the dot is the measured lift and the bar is its 95%
              anytime-valid interval against a zero line. Values are the difference between two
              conversion rates <strong>in points</strong>, not a relative change — 20% against
              30% reads as +10, not +50%. A bar crossing the zero line means "no difference" is
              still on the table. Intervals are <em>not</em> Holm-adjusted, so a bar can clear
              zero while the adjusted p-value sits above 0.05. "No data" means either arm has no
              eligible trials.
            </p>
          </div>
        </div>

        <div id="ex-abby-archive" class="ex-abby-show__block">
          <div :if={archived?(@report)} class="ex-abby-panel ex-abby-show__archive-row">
            <.status_pill experiment={@experiment} />
            <span :if={winner_variation(@experiment)}>
              Winner: <span class="ex-abby-mono">{winner_variation(@experiment).name}</span>
            </span>
            <button
              phx-click="unarchive"
              class="ex-abby-button ex-abby-button--secondary ex-abby-show__push-right"
            >
              Unarchive
            </button>
          </div>
          <form
            :if={!archived?(@report)}
            phx-submit="archive"
            class="ex-abby-panel ex-abby-show__archive-row"
          >
            <span class="ex-abby-show__archive-title">Archive this experiment</span>
            <label for="ex-abby-winner-variation" class="ex-abby-show__archive-hint">
              with winner
            </label>
            <select id="ex-abby-winner-variation" name="winner_variation_id" class="ex-abby-select">
              <option value="">No winner</option>
              <option :for={v <- @experiment.variations} value={v.id}>{v.name}</option>
            </select>
            <button
              type="submit"
              class="ex-abby-button ex-abby-button--danger ex-abby-show__push-right"
            >
              Archive experiment
            </button>
          </form>
        </div>
      </main>
    </div>
    """
  end

  attr(:report, :map, required: true)

  defp summary_strip(assigns) do
    ~H"""
    <div class="ex-abby-summary">
      <div class="ex-abby-summary__row">
        <div class={[
          "ex-abby-summary__headline",
          unavailable?(@report) && "ex-abby-summary__headline--warning"
        ]}>
          <.winner_headline report={@report} />
        </div>
        <div class="ex-abby-summary__stats">
          <div class="ex-abby-summary__stat">
            <span class="ex-abby-eyebrow">Trials</span>
            <div class="ex-abby-summary__stat-value">{format_count(@report.totals.trials)}</div>
          </div>
          <div class="ex-abby-summary__stat">
            <span class="ex-abby-eyebrow">Amount</span>
            <div class="ex-abby-summary__stat-value">
              {format_amount(@report.totals.success1.amount + @report.totals.success2.amount)}
            </div>
          </div>
          <div class="ex-abby-summary__stat">
            <span class="ex-abby-eyebrow">Best p</span>
            <div class={[
              "ex-abby-summary__stat-value",
              best_significant?(@report) && "ex-abby-summary__stat-value--significant"
            ]}>
              {best_p_text(@report)}
            </div>
          </div>
          <div class="ex-abby-summary__stat">
            <span class="ex-abby-eyebrow">Running</span>
            <div class="ex-abby-summary__stat-value">{@report.running_days}d</div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr(:report, :map, required: true)

  defp winner_headline(assigns) do
    ~H"""
    <%= case winner_headline_parts(@report) do %>
      <% :unavailable -> %>
        Significance is unavailable: no variation is named
        <span class="ex-abby-mono">{@report.control_variation_name}</span>.
      <% :none -> %>
        No significant difference yet.
      <% {:single, name, label} -> %>
        <span class="ex-abby-mono">{name}</span> is ahead on {label}.
      <% {:both, name} -> %>
        <span class="ex-abby-mono">{name}</span> is ahead on both metrics.
      <% {:split, name1, label1, name2, label2} -> %>
        <span class="ex-abby-mono">{name1}</span> is ahead on {label1};
        <span class="ex-abby-mono">{name2}</span> is ahead on {label2}.
    <% end %>
    """
  end

  attr(:report, :map, required: true)

  defp allocation_table(assigns) do
    assigns =
      assign(
        assigns,
        :scales,
        Map.new(assigns.report.metrics, &{&1, metric_scale(assigns.report, &1)})
      )

    ~H"""
    <div class="ex-abby-panel ex-abby-show__block">
      <div class="ex-abby-panel__header">
        <span class="ex-abby-eyebrow">Allocation & traffic</span>
      </div>
      <form phx-submit="save_weights">
        <div class="ex-abby-show__table-scroll">
          <table class="ex-abby-table">
            <thead>
              <tr>
                <th>Weight</th>
                <th>Variation</th>
                <th class="ex-abby-num">Trials</th>
                <%= for metric <- @report.metrics do %>
                  <th class="ex-abby-num">
                    {ExperimentReport.metric_label(@report.experiment, metric)} rate
                  </th>
                  <th class="ex-abby-num">Lift vs control</th>
                <% end %>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @report.summary} class={leader?(@report, row) && "ex-abby-row--leader"}>
                <td>
                  <input
                    type="number"
                    name={"weights[weight_#{row.variation_id}]"}
                    value={Map.fetch!(@report.weights_by_variation_id, row.variation_id)}
                    step="0.01"
                    min="0"
                    max="1"
                    class="ex-abby-input ex-abby-show__weight-input"
                    disabled={archived?(@report)}
                  />
                </td>
                <td class={[
                  "ex-abby-show__variation",
                  leader?(@report, row) && "ex-abby-show__variation--leader"
                ]}>
                  {row.variation_name}
                </td>
                <td class="ex-abby-num">{format_count(row.trials)}</td>
                <%= for metric <- @report.metrics do %>
                  <td class={rate_cell_class(@report, metric, row)}>
                    {format_rate(Map.fetch!(row, metric).rate)}
                  </td>
                  <.lift_cell
                    comparison={ExperimentReport.comparison(@report, metric, row.variation_id)}
                    scale={Map.fetch!(@scales, metric)}
                  />
                <% end %>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="ex-abby-panel__footer">
          <div class="ex-abby-show__footer-left">
            <button
              :if={!archived?(@report)}
              type="submit"
              class="ex-abby-button ex-abby-button--primary"
            >
              Save weights
            </button>
            <span class="ex-abby-mono ex-abby-muted">Σ {weights_sum(@report)}</span>
          </div>
          <div>Weights take effect on new assignments. Saving resets the measurement start time.</div>
        </div>
      </form>
    </div>
    """
  end

  attr(:comparison, :any, required: true)
  attr(:scale, :any, default: nil)

  defp lift_cell(assigns) do
    ~H"""
    <td class="ex-abby-show__lift-cell">
      <%= case @comparison do %>
        <% :control -> %>
          <span class="ex-abby-muted">baseline</span>
        <% :no_data -> %>
          <span class="ex-abby-faint">no data</span>
        <% :unavailable -> %>
          <span class="ex-abby-muted">—</span>
        <% comparison -> %>
          <div class="ex-abby-lift">
            <.lift_chart comparison={comparison} scale={@scale} width={104} />
            <span class={[
              "ex-abby-lift__label",
              comparison.significant? && "ex-abby-lift__label--significant"
            ]}>
              {format_points(comparison.lift)} · p {format_p(comparison.p_value)}
            </span>
          </div>
      <% end %>
    </td>
    """
  end

  attr(:report, :map, required: true)
  attr(:metric, :atom, required: true)

  defp metric_panel(assigns) do
    ~H"""
    <div class="ex-abby-panel ex-abby-show__block">
      <div class="ex-abby-panel__header">
        <h2 class="ex-abby-panel__title">
          {ExperimentReport.metric_label(@report.experiment, @metric)}
        </h2>
        <span class="ex-abby-panel__meta">{metric_meta(@report, @metric)}</span>
      </div>
      <table class="ex-abby-table">
        <thead>
          <tr>
            <th>Variation</th>
            <th class="ex-abby-num">Conv.</th>
            <th class="ex-abby-num">Unique</th>
            <th class="ex-abby-num">Amount</th>
            <th class="ex-abby-num">Rate</th>
            <th class="ex-abby-num">p</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={row <- @report.summary} class={leader?(@report, row) && "ex-abby-row--leader"}>
            <td class={[
              "ex-abby-show__variation",
              leader?(@report, row) && "ex-abby-show__variation--leader"
            ]}>
              {row.variation_name}
            </td>
            <td class="ex-abby-num">{format_count(Map.fetch!(row, @metric).count)}</td>
            <td class="ex-abby-num">{format_count(Map.fetch!(row, @metric).unique_count)}</td>
            <td class={["ex-abby-num", Map.fetch!(row, @metric).amount == 0 && "ex-abby-muted"]}>
              {format_amount(Map.fetch!(row, @metric).amount)}
            </td>
            <td class="ex-abby-num ex-abby-show__rate">
              {format_rate(Map.fetch!(row, @metric).rate)}
            </td>
            <% cell = metric_p_cell(ExperimentReport.comparison(@report, @metric, row.variation_id)) %>
            <td class={["ex-abby-num", cell.class]}>{cell.text}</td>
          </tr>
        </tbody>
      </table>
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
      report = ExperimentReport.build(experiment)

      socket
      |> assign(:report, report)
      |> assign(:experiment, report.experiment)
      |> assign(:updated?, false)
    else
      socket
    end
  end

  defp archived?(%ExperimentReport{experiment: %{archived_at: archived_at}}),
    do: not is_nil(archived_at)

  defp unavailable?(%ExperimentReport{significance: {:error, :control_not_found}}), do: true
  defp unavailable?(_report), do: false

  defp best_significant?(%ExperimentReport{best: %{significant?: true}}), do: true
  defp best_significant?(_report), do: false

  defp best_p_text(%ExperimentReport{best: nil}), do: "—"
  defp best_p_text(%ExperimentReport{best: best}), do: format_p(best.p_value)

  defp winner_headline_parts(%ExperimentReport{significance: {:error, :control_not_found}}),
    do: :unavailable

  defp winner_headline_parts(%ExperimentReport{winners: winners, metrics: metrics} = report) do
    present = for metric <- metrics, name = Map.get(winners, metric), name, do: {metric, name}

    case present do
      [] ->
        :none

      [{metric, name}] ->
        {:single, name, ExperimentReport.metric_label(report.experiment, metric)}

      [{_metric, name}, {_metric2, name}] ->
        {:both, name}

      [{metric1, name1}, {metric2, name2}] ->
        {:split, name1, ExperimentReport.metric_label(report.experiment, metric1), name2,
         ExperimentReport.metric_label(report.experiment, metric2)}
    end
  end

  # A shared horizontal scale, in percentage points, for one metric's lift
  # bars, so every bar in that column is comparable.
  defp metric_scale(report, metric) do
    report
    |> ExperimentReport.ready_comparisons()
    |> Enum.filter(&(&1.metric == metric))
    |> ExperimentReport.lift_scale()
  end

  # The leader is the winning arm of the best metric, which is control when
  # the best comparison is a significant loss.
  defp leader?(
         %ExperimentReport{best: %{significant?: true, metric: metric}, winners: winners},
         row
       ),
       do: Map.fetch!(winners, metric) == row.variation_name

  defp leader?(_report, _row), do: false

  defp rate_cell_class(report, metric, row) do
    [
      "ex-abby-num",
      "ex-abby-show__rate",
      Map.get(report.winners, metric) == row.variation_name && "ex-abby-significant"
    ]
  end

  defp metric_p_cell(:control), do: %{text: "Baseline", class: "ex-abby-muted"}
  defp metric_p_cell(:no_data), do: %{text: "No data", class: "ex-abby-muted"}
  defp metric_p_cell(:unavailable), do: %{text: "—", class: "ex-abby-muted"}

  defp metric_p_cell(%{p_value: p_value, significant?: true}),
    do: %{text: format_p(p_value), class: "ex-abby-significant"}

  defp metric_p_cell(%{p_value: p_value}), do: %{text: format_p(p_value), class: nil}

  defp metric_meta(report, metric) do
    totals = Map.fetch!(report.totals, metric)

    base =
      "#{format_count(totals.count)} conversions · #{format_count(totals.unique_count)} unique · significance on unique"

    if totals.amount > 0 do
      base <> " · #{format_amount(totals.amount)} total amount"
    else
      base
    end
  end

  defp weights_sum(report) do
    report.weights_by_variation_id
    |> Map.values()
    |> Enum.sum()
    |> Kernel.*(1.0)
    |> :erlang.float_to_binary(decimals: 2)
  end

  defp winner_variation(%{winner_variation_id: nil}), do: nil

  defp winner_variation(%{winner_variation_id: id, variations: variations}),
    do: Enum.find(variations, &(&1.id == id))

  defp validate_datetime(nil, _field), do: {:ok, nil}
  defp validate_datetime("", _field), do: {:ok, nil}

  defp validate_datetime(datetime_str, field) do
    case ExAbby.DatetimeParser.parse(datetime_str) do
      {:ok, _datetime} -> {:ok, datetime_str}
      nil -> {:error, "Invalid datetime field for '#{field}' field "}
    end
  end
end
