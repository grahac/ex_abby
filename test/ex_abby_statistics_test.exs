defmodule ExAbby.StatisticsTest do
  use ExUnit.Case, async: true

  alias ExAbby.Statistics

  describe "compare_to_control/3" do
    test "compares every treatment with control using Holm-adjusted anytime-valid p-values" do
      summary = [
        result(1, "control", 1_000, 100),
        result(2, "treatment_a", 1_000, 100),
        result(3, "treatment_b", 1_000, 250)
      ]

      assert {:ok, significance} = Statistics.compare_to_control(summary, :success1)

      assert significance.control_variation_id == 1
      assert significance.correction == :holm

      treatment_a = significance.comparisons[2]
      treatment_b = significance.comparisons[3]

      assert treatment_a.status == :ready
      assert treatment_a.raw_p_value == 1.0
      assert treatment_a.p_value == 1.0
      refute treatment_a.significant?

      assert treatment_b.status == :ready
      assert_in_delta treatment_b.raw_p_value, 0.0000000466186, 1.0e-12
      assert_in_delta treatment_b.p_value, 0.0000000932373, 1.0e-12
      assert treatment_b.significant?
    end

    test "uses unique conversions from the requested outcome" do
      summary = [
        result(1, "control", 1_000, 100, 100),
        result(2, "treatment", 1_000, 100, 250)
      ]

      assert {:ok, significance} = Statistics.compare_to_control(summary, :success2)

      comparison = significance.comparisons[2]
      assert comparison.status == :ready
      assert comparison.significant?
      assert comparison.p_value < 0.05
    end

    test "reports an anytime-valid comparison even when conversions are sparse" do
      summary = [
        result(1, "control", 100, 1),
        result(2, "treatment", 100, 5)
      ]

      assert {:ok, significance} = Statistics.compare_to_control(summary, :success1)
      assert significance.method == :beta_binomial_mixture_confidence_sequence
      assert significance.anytime_valid?

      comparison = significance.comparisons[2]
      assert comparison.status == :ready
      refute comparison.significant?
      assert comparison.p_value == 1.0
      assert_in_delta comparison.lift, 0.04, 1.0e-12
      assert_in_delta comparison.confidence_interval.lower, -0.0724872414, 1.0e-9
      assert_in_delta comparison.confidence_interval.upper, 0.1507760676, 1.0e-9
    end

    test "includes unavailable treatments in the multiple-comparison family" do
      summary = [
        result(1, "control", 1_000, 100),
        result(2, "ready", 1_000, 250),
        result(3, "too_sparse", 0, 0)
      ]

      assert {:ok, significance} = Statistics.compare_to_control(summary, :success1)

      assert_in_delta significance.comparisons[2].p_value, 0.0000000932373, 1.0e-12
      assert significance.comparisons[3] == %{status: :insufficient_data}
    end

    test "returns an error when the named control does not exist" do
      summary = [result(1, "baseline", 100, 10), result(2, "treatment", 100, 20)]

      assert {:error, :control_not_found} =
               Statistics.compare_to_control(summary, :success1, control_name: "control")
    end

    test "supports a configured control name" do
      summary = [result(1, "baseline", 100, 10), result(2, "treatment", 100, 20)]

      assert {:ok, significance} =
               Statistics.compare_to_control(summary, :success1, control_name: "baseline")

      assert significance.control_variation_id == 1
      assert significance.comparisons[2].status == :ready
    end

    test "uses the configured alpha for the decision and confidence sequence" do
      summary = [result(1, "control", 1_000, 100), result(2, "treatment", 1_000, 200)]

      assert {:ok, significance} =
               Statistics.compare_to_control(summary, :success1, alpha: 0.25)

      comparison = significance.comparisons[2]
      assert comparison.significant?
      assert comparison.confidence_interval.confidence_level == 0.75
      assert_in_delta comparison.confidence_interval.lower, 0.0332847338, 1.0e-9
      assert_in_delta comparison.confidence_interval.upper, 0.1657543346, 1.0e-9
    end

    test "rejects an invalid significance threshold" do
      summary = [result(1, "control", 100, 10), result(2, "treatment", 100, 20)]

      assert_raise ArgumentError, "alpha must be greater than 0 and at most 1", fn ->
        Statistics.compare_to_control(summary, :success1, alpha: 0)
      end
    end

    test "keeps the p-value symmetric while reporting lift in the treatment direction" do
      positive = [result(1, "control", 500, 50), result(2, "treatment", 500, 175)]
      negative = [result(1, "control", 500, 175), result(2, "treatment", 500, 50)]

      assert {:ok, positive_result} = Statistics.compare_to_control(positive, :success1)
      assert {:ok, negative_result} = Statistics.compare_to_control(negative, :success1)

      positive_comparison = positive_result.comparisons[2]
      negative_comparison = negative_result.comparisons[2]

      assert_in_delta positive_comparison.p_value, negative_comparison.p_value, 1.0e-12
      assert_in_delta positive_comparison.lift, -negative_comparison.lift, 1.0e-12

      assert_in_delta(
        positive_comparison.confidence_interval.lower,
        -negative_comparison.confidence_interval.upper,
        1.0e-12
      )

      assert_in_delta(
        positive_comparison.confidence_interval.upper,
        -negative_comparison.confidence_interval.lower,
        1.0e-12
      )
    end

    test "handles zero and complete conversion rates" do
      for conversions <- [0, 100] do
        summary = [
          result(1, "control", 100, conversions),
          result(2, "treatment", 100, conversions)
        ]

        assert {:ok, significance} = Statistics.compare_to_control(summary, :success1)

        comparison = significance.comparisons[2]
        assert comparison.status == :ready
        assert comparison.p_value == 1.0
        assert comparison.lift == 0.0
        assert comparison.confidence_interval.lower <= 0.0
        assert comparison.confidence_interval.upper >= 0.0
      end
    end
  end

  defp result(id, name, trials, success1_unique, success2_unique \\ 0) do
    %{
      variation_id: id,
      variation_name: name,
      trials: trials,
      success1: %{unique_count: success1_unique},
      success2: %{unique_count: success2_unique}
    }
  end
end
