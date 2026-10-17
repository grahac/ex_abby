defmodule ExAbby.Statistics do
  @moduledoc """
  Statistical comparisons for experiment summaries.

  Conversion outcomes are binary per trial, so comparisons use the unique
  conversion count rather than the total number of recorded success events.
  """

  @default_alpha 0.05
  # The normal mixture is tuned to give the narrowest interval at this many
  # trials per arm. Width changes slowly away from it, so one value suits both
  # small and large experiments.
  @tuning_trials 10_000
  @tuning_constant -2 * :math.log(@default_alpha) + :math.log(1 - 2 * :math.log(@default_alpha))

  @doc """
  Compares each treatment in an experiment summary with the named control.

  The returned p-values invert a two-sided asymptotic confidence sequence for
  the difference in conversion rates (Waudby-Smith et al., 2024, "Time-uniform
  central limit theory and asymptotic confidence sequences"). They remain valid
  under continuous monitoring and are adjusted together with Holm's method. The
  correction family is every treatment in `summary`, including those returned as
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
               method: :asymptotic_confidence_sequence,
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
      lift = treatment_conversions / treatment_trials - control_conversions / control_trials

      control_variance = rate_variance(control_trials, control_conversions)
      treatment_variance = rate_variance(treatment_trials, treatment_conversions)
      variance = control_variance / control_trials + treatment_variance / treatment_trials

      mixture_variance =
        @tuning_constant * (control_variance + treatment_variance) / @tuning_trials

      half_width = half_width(variance, mixture_variance, alpha)
      {lower, upper} = {max(-1.0, lift - half_width), min(1.0, lift + half_width)}

      raw_p_value =
        min(1.0, :math.exp(-log_likelihood_ratio(lift, variance, mixture_variance)))

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

  # Smoothed so an arm with no conversions, or only conversions, still has
  # positive variance.
  defp rate_variance(trials, conversions) do
    rate = (conversions + 1) / (trials + 2)
    rate * (1.0 - rate)
  end

  # Likelihood ratio of a N(0, mixture_variance) mixture of lifts against zero
  # lift. Ville's inequality bounds the chance it ever exceeds 1 / alpha under
  # the null, which is what makes the p-value safe to read at any time.
  defp log_likelihood_ratio(lift, variance, mixture_variance) do
    total = variance + mixture_variance

    0.5 * :math.log(variance / total) +
      lift * lift * mixture_variance / (2.0 * variance * total)
  end

  # The lifts whose likelihood ratio stays below 1 / alpha.
  defp half_width(variance, mixture_variance, alpha) do
    total = variance + mixture_variance

    :math.sqrt(
      variance * total / mixture_variance *
        (2.0 * :math.log(1.0 / alpha) + :math.log(total / variance))
    )
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
