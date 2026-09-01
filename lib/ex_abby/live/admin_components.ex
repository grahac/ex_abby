defmodule ExAbby.Live.AdminComponents do
  @moduledoc false

  use Phoenix.Component

  @doc """
  Lift-versus-control chart: a dot at the measured lift and a bar for its 95%
  anytime-valid interval, drawn against a zero line on a shared `scale`
  (in percentage points).
  """
  attr(:comparison, :map, required: true)
  attr(:scale, :float, required: true)
  attr(:width, :integer, default: 120)

  def lift_chart(assigns) do
    ~H"""
    <svg
      class={["ex-abby-lift__chart", @comparison.significant? && "ex-abby-lift__chart--significant"]}
      width={@width}
      height="14"
      viewBox="0 0 120 16"
      role="img"
    >
      <title>{chart_title(@comparison)}</title>
      <line class="ex-abby-lift__zero" x1="60" y1="1" x2="60" y2="15" />
      <line
        class="ex-abby-lift__range"
        x1={chart_x(@comparison.confidence_interval.lower, @scale)}
        y1="8"
        x2={chart_x(@comparison.confidence_interval.upper, @scale)}
        y2="8"
      />
      <circle class="ex-abby-lift__point" cx={chart_x(@comparison.lift, @scale)} cy="8" r="3.2" />
    </svg>
    """
  end

  @doc """
  Running/Archived status pill for an experiment.
  """
  attr(:experiment, :map, required: true)

  def status_pill(assigns) do
    ~H"""
    <span
      :if={is_nil(@experiment.archived_at)}
      class="ex-abby-pill ex-abby-pill--running"
    >
      Running
    </span>
    <span :if={@experiment.archived_at} class="ex-abby-pill ex-abby-pill--archived">
      Archived
    </span>
    """
  end

  @doc """
  Shared top bar: brand or breadcrumb on the left, actions on the right.
  """
  slot(:crumbs, required: true)
  slot(:actions)

  def topbar(assigns) do
    ~H"""
    <div class="ex-abby-topbar">
      <div class="ex-abby-topbar__crumbs">{render_slot(@crumbs)}</div>
      <div class="ex-abby-topbar__actions">{render_slot(@actions)}</div>
    </div>
    """
  end

  defp chart_x(proportion, scale) do
    points = max(-scale, min(scale, proportion * 100))
    Float.round(60.0 + points / scale * 58.0, 2)
  end

  defp chart_title(comparison) do
    "lift #{format_points(comparison.lift)} points, 95% interval " <>
      "#{format_points(comparison.confidence_interval.lower)} to " <>
      "#{format_points(comparison.confidence_interval.upper)}"
  end

  @doc "Signed lift in percentage points: `+2.8`, `-0.4`, `0.0`."
  def format_points(proportion) do
    value = Float.round(proportion * 100, 1)
    formatted = :erlang.float_to_binary(value, decimals: 1)
    if value > 0.0, do: "+" <> formatted, else: formatted
  end

  @doc "Conversion rate as a percentage: `11.25%`."
  def format_rate(rate), do: :erlang.float_to_binary(rate * 100, decimals: 2) <> "%"

  @doc "Adjusted p-value: `< 0.001` or three decimals."
  def format_p(p_value) when p_value < 0.001, do: "< 0.001"
  def format_p(p_value), do: :erlang.float_to_binary(p_value, decimals: 3)

  @doc "Monetary amount with thousands separators and two decimals."
  def format_amount(amount) do
    [whole, fraction] =
      amount
      |> Kernel.*(1.0)
      |> :erlang.float_to_binary(decimals: 2)
      |> String.split(".")

    group_thousands(whole) <> "." <> fraction
  end

  @doc "Integer with thousands separators: `25,908`."
  def format_count(count) when is_integer(count), do: group_thousands(Integer.to_string(count))

  defp group_thousands("-" <> digits), do: "-" <> group_thousands(digits)

  defp group_thousands(digits) do
    digits
    |> String.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.join(",")
  end
end
