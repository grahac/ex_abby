defmodule ExAbby.Live.ExperimentIndexLive do
  @moduledoc """
  Lists all ex_abby experiments with their best result, health and running time.
  """
  use Phoenix.LiveView
  import ExAbby.Live.AdminComponents
  alias ExAbby.{ExperimentReport, Experiments}

  @spec mount(any(), any(), map()) :: {:ok, map()}
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:filter, :active)
     |> assign(:query, "")
     |> load_reports()
     |> assign(:page_title, "ExAbby - Index")}
  end

  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:filter, filter_atom(status))
     |> load_reports()}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:query, query)}
  end

  defp load_reports(socket) do
    filter = socket.assigns.filter

    assign_async(
      socket,
      :report_data,
      fn ->
        experiments = Experiments.list_experiments()

        reports =
          experiments
          |> Enum.filter(&matches_filter?(&1, filter))
          |> Enum.map(&ExperimentReport.build/1)

        {:ok, %{report_data: %{experiments: experiments, reports: reports}}}
      end,
      reset: true
    )
  end

  defp filter_atom("active"), do: :active
  defp filter_atom("archived"), do: :archived
  defp filter_atom("all"), do: :all

  defp derive_view(%{report_data: %{ok?: true, result: data}} = assigns) do
    %{filter: filter, query: query} = assigns
    %{experiments: experiments, reports: loaded_reports} = data

    counts = %{
      running: Enum.count(experiments, &is_nil(&1.archived_at)),
      significant: Enum.count(loaded_reports, &significant?/1),
      archived: Enum.count(experiments, & &1.archived_at)
    }

    reports =
      loaded_reports
      |> Enum.filter(&matches_query?(&1, query))

    scale =
      reports
      |> Enum.map(& &1.best)
      |> Enum.reject(&is_nil/1)
      |> ExperimentReport.lift_scale()
      |> Kernel.||(1.0)

    archived =
      if filter == :active do
        experiments
        |> Enum.filter(& &1.archived_at)
        |> Enum.sort_by(& &1.archived_at, {:desc, DateTime})
        |> Enum.take(3)
      else
        []
      end

    assigns
    |> assign(:counts, counts)
    |> assign(:reports, reports)
    |> assign(:archived, archived)
    |> assign(:scale, scale)
  end

  defp derive_view(assigns) do
    assign(assigns, counts: nil, reports: [], archived: [], scale: 1.0)
  end

  defp significant?(%{best: nil}), do: false
  defp significant?(%{best: best}), do: best.significant?

  defp matches_filter?(_experiment, :all), do: true
  defp matches_filter?(experiment, :active), do: is_nil(experiment.archived_at)
  defp matches_filter?(experiment, :archived), do: !is_nil(experiment.archived_at)

  defp matches_query?(_report, ""), do: true

  defp matches_query?(report, query) do
    String.contains?(String.downcase(report.experiment.name), String.downcase(query))
  end

  defp health_label(:healthy), do: "Healthy"
  defp health_label(:low_traffic), do: "Low traffic"
  defp health_label(:high_exclusion), do: "High exclusions"
  defp health_label(:skewed_split), do: "Skewed split"

  defp row_class(%{best: best, health: health}) do
    cond do
      best && best.significant? -> "ex-abby-row--significant"
      health != :healthy -> "ex-abby-row--warning"
      true -> nil
    end
  end

  defp winner_name(%{winner_variation_id: id, variations: variations}) do
    Enum.find_value(variations, fn v -> v.id == id && v.name end)
  end

  defp format_scale(scale) when scale == trunc(scale), do: Integer.to_string(trunc(scale))
  defp format_scale(scale), do: :erlang.float_to_binary(scale, decimals: 1)

  def render(assigns) do
    assigns = derive_view(assigns)

    ~H"""
    <ExAbby.Live.AdminStyle.styles />
    <style>
      .ex-abby-admin .ex-abby-index__description {
        margin-top: 0.25rem;
        color: var(--ex-abby-color-ink-muted);
        font-size: 0.75rem;
        text-wrap: pretty;
      }

      .ex-abby-admin .ex-abby-index__table {
        margin-top: 1.5rem;
      }

      .ex-abby-admin .ex-abby-index__archived {
        margin-top: 1.25rem;
      }

      .ex-abby-admin .ex-abby-toolbar {
        display: flex;
        align-items: center;
        gap: 0.5rem;
      }

      .ex-abby-admin .ex-abby-health--warning {
        color: var(--ex-abby-color-warning);
        font-weight: 600;
      }

      .ex-abby-admin .ex-abby-row-link {
        position: relative;
        cursor: pointer;
      }

      .ex-abby-admin .ex-abby-row-link__anchor {
        color: var(--ex-abby-color-ink);
        font-family: var(--ex-abby-font-mono);
        font-weight: 600;
        text-decoration: none;
      }

      .ex-abby-admin .ex-abby-row-link__anchor::after {
        content: "";
        position: absolute;
        inset: 0;
      }

      .ex-abby-admin .ex-abby-panel__action {
        margin-left: auto;
        padding: 0;
        background: none;
        border: none;
        color: var(--ex-abby-color-accent);
        cursor: pointer;
        font-size: 0.8125rem;
        font-weight: 500;
      }

      .ex-abby-admin .ex-abby-panel__action:hover {
        color: var(--ex-abby-color-accent-deep);
        text-decoration: underline;
      }
    </style>

    <div class="ex-abby-admin">
      <.topbar>
        <:crumbs>
          <span class="ex-abby-topbar__brand">ex_abby</span>
          <span class="ex-abby-eyebrow">Experiments</span>
        </:crumbs>
        <:actions>
          <.link navigate="trials" class="ex-abby-topbar__link">Edit trials for session</.link>
        </:actions>
      </.topbar>

      <main class="ex-abby-admin__shell ex-abby-admin__shell--narrow">
        <header class="ex-abby-admin__header">
          <div>
            <h1 class="ex-abby-admin__title">Experiments</h1>
            <p :if={@counts} class="ex-abby-admin__subtitle">
              {@counts.running} running · {@counts.significant} with a significant result in this tab · {@counts.archived} archived
            </p>
          </div>
          <div class="ex-abby-toolbar">
            <form id="ex-abby-index-search" phx-change="search" phx-submit="search">
              <input
                type="text"
                name="query"
                value={@query}
                placeholder="Filter by name"
                aria-label="Filter experiments by name"
                phx-debounce="200"
                class="ex-abby-input"
              />
            </form>
            <div class="ex-abby-segmented">
              <button
                type="button"
                class={@filter == :active && "active"}
                aria-pressed={@filter == :active}
                phx-click="filter"
                phx-value-status="active"
              >
                Running
              </button>
              <button
                type="button"
                class={@filter == :archived && "active"}
                aria-pressed={@filter == :archived}
                phx-click="filter"
                phx-value-status="archived"
              >
                Archived
              </button>
              <button
                type="button"
                class={@filter == :all && "active"}
                aria-pressed={@filter == :all}
                phx-click="filter"
                phx-value-status="all"
              >
                All
              </button>
            </div>
          </div>
        </header>

        <.async_result assign={@report_data}>
          <:loading>
            <div class="ex-abby-empty-state" role="status">Loading experiments…</div>
          </:loading>
          <:failed>
            <div class="ex-abby-empty-state" role="alert">
              Could not load experiment results. Reload to try again.
            </div>
          </:failed>
        </.async_result>
        <div :if={@report_data.ok?} class="ex-abby-table-frame ex-abby-index__table">
          <table class="ex-abby-table">
            <thead>
              <tr>
                <th>Experiment</th>
                <th>Best lift &amp; p</th>
                <th>Health</th>
                <th class="ex-abby-num">Running</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={r <- @reports} class={["ex-abby-row-link", row_class(r)]}>
                <td>
                  <.link navigate={"#{r.experiment.id}"} class="ex-abby-row-link__anchor">
                    {r.experiment.name}
                  </.link>
                  <div class="ex-abby-index__description">{r.experiment.description}</div>
                </td>
                <td>
                  <div :if={r.best} class="ex-abby-lift ex-abby-lift--start">
                    <.lift_chart comparison={r.best} scale={@scale} width={120} />
                    <span class={[
                      "ex-abby-lift__label",
                      r.best.significant? && "ex-abby-lift__label--significant"
                    ]}>
                      p {format_p(r.best.p_value)}
                    </span>
                  </div>
                  <span :if={!r.best} class="ex-abby-muted">—</span>
                </td>
                <td class={r.health != :healthy && "ex-abby-health--warning"}>
                  {health_label(r.health)}
                </td>
                <td class="ex-abby-num">{r.running_days}d</td>
              </tr>
            </tbody>
          </table>
          <div :if={Enum.empty?(@reports)} class="ex-abby-empty-state">
            No experiments match this filter.
          </div>
          <div class="ex-abby-panel__footer">
            The bar is the best metric's lift against control in points, with its 95% interval, on a shared ±{format_scale(
              @scale
            )} point scale. Green marks a Holm-adjusted p below 0.05. Health flags low traffic, a skewed split or an exclusion rate above 10%. Open an experiment for rates, counts and amounts.
          </div>
        </div>

        <div :if={@filter == :active and @archived != []} class="ex-abby-panel ex-abby-index__archived">
          <div class="ex-abby-panel__header">
            <h2 class="ex-abby-panel__title">Recently archived</h2>
            <span class="ex-abby-panel__meta">{@counts.archived} total</span>
            <button
              type="button"
              class="ex-abby-panel__action"
              phx-click="filter"
              phx-value-status="archived"
            >
              See all archived
            </button>
          </div>
          <table class="ex-abby-table">
            <tbody>
              <tr :for={experiment <- @archived}>
                <td>
                  <.link navigate={"#{experiment.id}"} class="ex-abby-mono">
                    {experiment.name}
                  </.link>
                </td>
                <td class="ex-abby-muted">
                  <span :if={is_nil(experiment.winner_variation_id)}>No winner</span>
                  <span :if={experiment.winner_variation_id}>
                    Winner <span class="ex-abby-mono">{winner_name(experiment)}</span>
                  </span>
                </td>
                <td class="ex-abby-num ex-abby-muted">
                  Archived {Calendar.strftime(experiment.archived_at, "%-d %b %Y")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </main>
    </div>
    """
  end
end
