defmodule ExAbby.ExperimentReport do
  @moduledoc """
  Read model behind the admin experiment pages.

  Combines an experiment's summary rows with control-relative significance and
  derives the figures both admin pages show: the best comparison, per-metric
  winners, totals, a health flag and how long the experiment has been running.
  """

  alias ExAbby.{Experiment, Experiments, Statistics}

  @low_traffic_trials 100
  @skew_tolerance 0.10
  @exclusion_limit 0.10
  @scale_steps [1.0, 2.0, 5.0, 10.0, 25.0, 50.0, 100.0]

  defstruct [
    :experiment,
    :summary,
    :metrics,
    :control_variation_name,
    :significance,
    :best,
    :winners,
    :health,
    :running_days,
    :totals,
    :weights_by_variation_id
  ]

  @doc """
  Builds a report for every experiment matching `status` (`:active`,
  `:archived` or `:all`), newest first.
  """
  def list(status) do
    [status: status]
    |> Experiments.list_experiments()
    |> Enum.map(&build/1)
  end

  @doc """
  Builds the report for one experiment from the database.
  """
  def build(%Experiment{} = experiment) do
    summary = Experiments.experiment_summary(experiment)
    from_summary(experiment, summary, DateTime.utc_now())
  end

  @doc """
  Builds the report from an experiment and its summary rows without touching
  the database. `now` bounds the running time of an active experiment.
  """
  def from_summary(%Experiment{} = experiment, summary, %DateTime{} = now) do
    control_variation_name = Application.get_env(:ex_abby, :control_variation_name, "control")

    metrics =
      if show_success2?(experiment, summary), do: [:success1, :success2], else: [:success1]

    significance =
      Statistics.compare_metrics_to_control(summary, metrics,
        control_name: control_variation_name
      )

    comparisons = ready_comparisons(significance, summary)

    %__MODULE__{
      experiment: experiment,
      summary: summary,
      metrics: metrics,
      control_variation_name: control_variation_name,
      significance: significance,
      best: Enum.min_by(comparisons, & &1.p_value, fn -> nil end),
      winners: Map.new(metrics, &{&1, winner(comparisons, &1, control_variation_name)}),
      health: health(experiment, summary),
      running_days: running_days(experiment, now),
      totals: totals(summary),
      weights_by_variation_id: Map.new(experiment.variations, &{&1.id, &1.weight})
    }
  end

  @doc """
  Whether the second success metric is configured or has recorded conversions.
  """
  def show_success2?(%Experiment{} = experiment, summary) do
    has_label = experiment.success2_label && experiment.success2_label != ""
    has_conversions = Enum.any?(summary, fn row -> row.success2.count > 0 end)
    (has_label || has_conversions) == true
  end

  @doc """
  Label for a metric, falling back to the generic "Success" label the admin
  has always used when none is configured.
  """
  def metric_label(%Experiment{} = experiment, :success1),
    do: experiment.success1_label || "Success"

  def metric_label(%Experiment{} = experiment, :success2),
    do: experiment.success2_label || "Success 2"

  @doc """
  The significance cell for one variation and metric: `:unavailable` when
  there is no control, `:control` for the control arm, `:no_data` when either
  arm has no trials, or a ready comparison map.
  """
  def comparison(%__MODULE__{significance: {:error, :control_not_found}}, _metric, _id),
    do: :unavailable

  def comparison(%__MODULE__{significance: {:ok, by_metric}}, metric, variation_id) do
    %{control_variation_id: control_id, comparisons: comparisons} = Map.fetch!(by_metric, metric)

    cond do
      variation_id == control_id -> :control
      match?(%{status: :insufficient_data}, Map.fetch!(comparisons, variation_id)) -> :no_data
      true -> Map.fetch!(comparisons, variation_id)
    end
  end

  @doc """
  Every ready comparison in the report as flat maps carrying `:metric`,
  `:variation_id` and `:variation_name`.
  """
  def ready_comparisons(%__MODULE__{significance: significance, summary: summary}),
    do: ready_comparisons(significance, summary)

  @doc """
  A shared horizontal scale, in percentage points, wide enough for every
  interval in `comparisons`, so bars drawn together are comparable.
  """
  def lift_scale([]), do: nil

  def lift_scale(comparisons) do
    widest =
      comparisons
      |> Enum.map(fn %{confidence_interval: interval} ->
        max(abs(interval.lower), abs(interval.upper)) * 100
      end)
      |> Enum.max()

    Enum.find(@scale_steps, 100.0, &(&1 >= widest))
  end

  defp ready_comparisons({:error, :control_not_found}, _summary), do: []

  defp ready_comparisons({:ok, by_metric}, summary) do
    names = Map.new(summary, &{&1.variation_id, &1.variation_name})

    for {metric, %{comparisons: comparisons}} <- by_metric,
        {variation_id, %{status: :ready} = comparison} <- comparisons do
      Map.merge(comparison, %{
        metric: metric,
        variation_id: variation_id,
        variation_name: Map.fetch!(names, variation_id)
      })
    end
  end

  # The winner for a metric is the arm on the good side of the largest
  # significant difference: the treatment when it lifted, control when it hurt.
  defp winner(comparisons, metric, control_variation_name) do
    comparisons
    |> Enum.filter(&(&1.metric == metric and &1.significant?))
    |> Enum.max_by(&abs(&1.lift), fn -> nil end)
    |> case do
      nil -> nil
      %{lift: lift} when lift < 0 -> control_variation_name
      %{variation_name: name} -> name
    end
  end

  defp health(%Experiment{variations: variations}, summary) do
    total = Enum.sum(Enum.map(summary, & &1.trials))
    excluded = Enum.sum(Enum.map(summary, & &1.excluded_trials))

    cond do
      total < @low_traffic_trials -> :low_traffic
      excluded / (total + excluded) > @exclusion_limit -> :high_exclusion
      skewed_split?(variations, summary, total) -> :skewed_split
      true -> :healthy
    end
  end

  defp skewed_split?(variations, summary, total) do
    weight_total = Enum.sum(Enum.map(variations, & &1.weight))
    weights = Map.new(variations, &{&1.id, &1.weight})

    weight_total > 0 and
      Enum.any?(summary, fn row ->
        expected = Map.fetch!(weights, row.variation_id) / weight_total
        abs(row.trials / total - expected) > @skew_tolerance
      end)
  end

  # Measurement starts at the experiment's start time when one is set and
  # parses, matching `experiment_summary/1`; otherwise at creation.
  defp running_days(%Experiment{} = experiment, now) do
    started =
      case ExAbby.DatetimeParser.parse(experiment.start_time) do
        {:ok, datetime} -> datetime
        nil -> DateTime.from_naive!(experiment.inserted_at, "Etc/UTC")
      end

    ended = experiment.archived_at || now

    max(0, div(DateTime.diff(ended, started, :second), 86_400))
  end

  defp totals(summary) do
    %{
      trials: Enum.sum(Enum.map(summary, & &1.trials)),
      success1: metric_totals(summary, :success1),
      success2: metric_totals(summary, :success2)
    }
  end

  defp metric_totals(summary, metric) do
    %{
      count: Enum.sum(Enum.map(summary, &Map.fetch!(&1, metric).count)),
      unique_count: Enum.sum(Enum.map(summary, &Map.fetch!(&1, metric).unique_count)),
      amount: Enum.sum(Enum.map(summary, &(Map.fetch!(&1, metric).amount * 1.0)))
    }
  end
end
