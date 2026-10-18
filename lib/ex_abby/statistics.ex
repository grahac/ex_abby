defmodule ExAbby.Statistics do
  @moduledoc """
  Statistical comparisons for experiment summaries.

  Conversion outcomes are binary per trial, so comparisons use the unique
  conversion count rather than the total number of recorded success events.
  """

  @default_alpha 0.05
  @mixture_strength 10.0
  @boundary_epsilon 1.0e-12
  @p_value_iterations 60
  @root_iterations 60
  @lanczos_g 7.0
  @log_sqrt_two_pi 0.9189385332046727
  @lanczos_coefficients [
    0.9999999999998099,
    676.5203681218851,
    -1259.1392167224028,
    771.3234287776531,
    -176.6150291621406,
    12.507343278686905,
    -0.13857109526572012,
    9.984369578019572e-6,
    1.5056327351493116e-7
  ]

  @doc """
  Compares each treatment in an experiment summary with the named control.

  The returned p-values invert two-sided beta-binomial mixture confidence
  sequences for Bernoulli outcomes. They remain valid under continuous
  monitoring and are adjusted together with Holm's method. The correction family
  is every treatment in `summary`, including those returned as
  `:insufficient_data`, so that the family is fixed by the experiment's design
  rather than by which arms currently have data.

  Each comparison also includes an anytime-valid confidence sequence for
  treatment-minus-control lift. That interval is built at `:alpha` and is *not*
  Holm-adjusted, so with several treatments an interval can exclude zero while
  the same comparison's adjusted `:p_value` exceeds `:alpha`. Use `:p_value` for
  the decision and `:confidence_interval` for the magnitude.

  A comparison is marked `:insufficient_data` only when either arm has no valid
  trials. Sparse conversion counts produce a wide confidence sequence instead
  of suppressing the result.

  Options:

    * `:control_name` - control variation name, defaults to `"control"`
    * `:alpha` - significance threshold, defaults to `#{@default_alpha}`
  """
  def compare_to_control(summary, metric, opts \\ [])
      when is_list(summary) and metric in [:success1, :success2] do
    case compare_metrics_to_control(summary, [metric], opts) do
      {:ok, significance_by_metric} -> {:ok, Map.fetch!(significance_by_metric, metric)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Compares several success metrics with control as one Holm correction family.

  A treatment can be significant for any requested metric; the other metrics do
  not also need to be significant. Combining the metrics into one family keeps
  the overall false-positive rate at `:alpha` when any metric can identify a
  winner.

  The returned map contains the same significance result as
  `compare_to_control/3` for each requested metric. Every configured treatment
  and requested metric remains in the family even when it has insufficient data.
  """
  def compare_metrics_to_control(summary, metrics, opts \\ [])
      when is_list(summary) and is_list(metrics) do
    metrics = Enum.uniq(metrics)
    validate_metrics!(metrics)

    control_name = Keyword.get(opts, :control_name, "control")
    alpha = Keyword.get(opts, :alpha, @default_alpha)
    validate_alpha!(alpha)

    case Enum.find(summary, &(&1.variation_name == control_name)) do
      nil ->
        {:error, :control_not_found}

      control ->
        treatments = Enum.reject(summary, &(&1.variation_id == control.variation_id))
        family_size = length(treatments) * length(metrics)

        comparisons =
          for metric <- metrics, treatment <- treatments do
            control
            |> compare_pair(treatment, metric, alpha)
            |> Map.put(:metric, metric)
          end
          |> holm_adjust(family_size, alpha)
          |> Enum.group_by(& &1.metric)

        significance_by_metric =
          Map.new(metrics, fn metric ->
            metric_comparisons =
              comparisons
              |> Map.get(metric, [])
              |> Map.new(fn comparison ->
                {comparison.variation_id, Map.drop(comparison, [:metric, :variation_id])}
              end)

            {metric,
             %{
               alpha: alpha,
               anytime_valid?: true,
               comparisons: metric_comparisons,
               control_name: control_name,
               control_variation_id: control.variation_id,
               correction: :holm,
               correction_family: metrics,
               correction_family_size: family_size,
               method: :beta_binomial_mixture_confidence_sequence,
               metric: metric
             }}
          end)

        {:ok, significance_by_metric}
    end
  end

  defp compare_pair(control, treatment, metric, alpha) do
    control_trials = control.trials
    treatment_trials = treatment.trials
    control_conversions = get_in(control, [metric, :unique_count])
    treatment_conversions = get_in(treatment, [metric, :unique_count])

    if valid_data?(
         control_trials,
         control_conversions,
         treatment_trials,
         treatment_conversions
       ) do
      control_rate = control_conversions / control_trials
      treatment_rate = treatment_conversions / treatment_trials
      lift = treatment_rate - control_rate

      {lower, upper} =
        lift_confidence_sequence(
          control_trials,
          control_conversions,
          treatment_trials,
          treatment_conversions,
          alpha
        )

      raw_p_value =
        anytime_p_value(
          control_trials,
          control_conversions,
          treatment_trials,
          treatment_conversions
        )

      %{
        confidence_interval: %{
          confidence_level: 1.0 - alpha,
          lower: lower,
          upper: upper
        },
        lift: lift,
        variation_id: treatment.variation_id,
        raw_p_value: raw_p_value,
        status: :ready
      }
    else
      %{variation_id: treatment.variation_id, status: :insufficient_data}
    end
  end

  defp valid_data?(
         control_trials,
         control_conversions,
         treatment_trials,
         treatment_conversions
       )
       when is_integer(control_trials) and is_integer(control_conversions) and
              is_integer(treatment_trials) and is_integer(treatment_conversions) and
              control_trials > 0 and treatment_trials > 0 and control_conversions >= 0 and
              treatment_conversions >= 0 and control_conversions <= control_trials and
              treatment_conversions <= treatment_trials,
       do: true

  defp valid_data?(_, _, _, _), do: false

  defp anytime_p_value(
         control_trials,
         control_conversions,
         treatment_trials,
         treatment_conversions
       ) do
    if pair_excludes_zero?(
         control_trials,
         control_conversions,
         treatment_trials,
         treatment_conversions,
         1.0
       ) do
      Enum.reduce(1..@p_value_iterations, {0.0, 1.0}, fn _, {lower, upper} ->
        midpoint = (lower + upper) / 2.0

        if pair_excludes_zero?(
             control_trials,
             control_conversions,
             treatment_trials,
             treatment_conversions,
             midpoint
           ) do
          {lower, midpoint}
        else
          {midpoint, upper}
        end
      end)
      |> elem(1)
    else
      1.0
    end
  end

  defp pair_excludes_zero?(
         control_trials,
         control_conversions,
         treatment_trials,
         treatment_conversions,
         alpha
       ) do
    {lower, upper} =
      lift_confidence_sequence(
        control_trials,
        control_conversions,
        treatment_trials,
        treatment_conversions,
        alpha
      )

    lower > 0.0 or upper < 0.0
  end

  defp lift_confidence_sequence(
         control_trials,
         control_conversions,
         treatment_trials,
         treatment_conversions,
         alpha
       ) do
    arm_alpha = alpha / 2.0

    {control_lower, control_upper} =
      bernoulli_confidence_sequence(control_trials, control_conversions, arm_alpha)

    {treatment_lower, treatment_upper} =
      bernoulli_confidence_sequence(treatment_trials, treatment_conversions, arm_alpha)

    {
      max(-1.0, treatment_lower - control_upper),
      min(1.0, treatment_upper - control_lower)
    }
  end

  defp bernoulli_confidence_sequence(trials, conversions, alpha) do
    estimate = conversions / trials
    threshold = :math.log(1.0 / alpha)

    lower =
      if conversions == 0 do
        0.0
      else
        boundary_root(@boundary_epsilon, estimate, threshold, trials, conversions, :lower)
      end

    upper =
      if conversions == trials do
        1.0
      else
        boundary_root(
          estimate,
          1.0 - @boundary_epsilon,
          threshold,
          trials,
          conversions,
          :upper
        )
      end

    {lower, upper}
  end

  defp boundary_root(lower, upper, threshold, trials, conversions, side) do
    {lower, upper} =
      Enum.reduce(1..@root_iterations, {lower, upper}, fn _, {lower, upper} ->
        midpoint = (lower + upper) / 2.0
        excluded? = log_mixture_e_value(midpoint, trials, conversions) >= threshold

        case {side, excluded?} do
          {:lower, true} -> {midpoint, upper}
          {:lower, false} -> {lower, midpoint}
          {:upper, true} -> {lower, midpoint}
          {:upper, false} -> {midpoint, upper}
        end
      end)

    if side == :lower, do: upper, else: lower
  end

  # For each hypothesized Bernoulli mean, this is the log likelihood ratio
  # between a beta mixture of alternatives and that point null. It is a
  # nonnegative martingale under the point null, so Ville's inequality makes
  # its inversion a confidence sequence (Howard et al., 2021, two-sided
  # beta-binomial mixture boundary).
  defp log_mixture_e_value(mean, trials, conversions) do
    prior_success = @mixture_strength * mean
    prior_failure = @mixture_strength * (1.0 - mean)

    log_beta(conversions + prior_success, trials - conversions + prior_failure) -
      log_beta(prior_success, prior_failure) -
      conversions * :math.log(mean) -
      (trials - conversions) * :math.log(1.0 - mean)
  end

  defp log_beta(left, right) do
    log_gamma(left) + log_gamma(right) - log_gamma(left + right)
  end

  defp log_gamma(value) when value < 0.5 do
    :math.log(:math.pi()) - :math.log(:math.sin(:math.pi() * value)) -
      log_gamma(1.0 - value)
  end

  defp log_gamma(value) do
    shifted = value - 1.0
    [first | rest] = @lanczos_coefficients

    series =
      rest
      |> Enum.with_index(1)
      |> Enum.reduce(first, fn {coefficient, index}, sum ->
        sum + coefficient / (shifted + index)
      end)

    scale = shifted + @lanczos_g + 0.5

    @log_sqrt_two_pi + (shifted + 0.5) * :math.log(scale) - scale + :math.log(series)
  end

  defp validate_alpha!(alpha) when is_number(alpha) and alpha > 0 and alpha <= 1, do: :ok

  defp validate_alpha!(_alpha) do
    raise ArgumentError, "alpha must be greater than 0 and at most 1"
  end

  defp validate_metrics!([]) do
    raise ArgumentError, "at least one success metric is required"
  end

  defp validate_metrics!(metrics) do
    unless Enum.all?(metrics, &(&1 in [:success1, :success2])) do
      raise ArgumentError, "metrics must contain only :success1 or :success2"
    end
  end

  defp holm_adjust(comparisons, family_size, alpha) do
    ready =
      comparisons
      |> Enum.filter(&(&1.status == :ready))
      |> Enum.sort_by(& &1.raw_p_value)

    {_previous_p_value, adjusted_by_variation} =
      ready
      |> Enum.with_index(1)
      |> Enum.reduce({0.0, %{}}, fn {comparison, rank}, {previous_p_value, adjusted} ->
        adjusted_p_value =
          comparison.raw_p_value
          |> Kernel.*(family_size - rank + 1)
          |> max(previous_p_value)
          |> min(1.0)

        result =
          comparison
          |> Map.put(:p_value, adjusted_p_value)
          |> Map.put(:significant?, adjusted_p_value < alpha)

        key = {comparison.metric, comparison.variation_id}
        {adjusted_p_value, Map.put(adjusted, key, result)}
      end)

    Enum.map(comparisons, fn comparison ->
      Map.get(adjusted_by_variation, {comparison.metric, comparison.variation_id}, comparison)
    end)
  end
end
