defmodule ExampleApp.ExperimentSignificanceLiveTest do
  use ExampleAppWeb.ConnCase

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias ExAbby.{Experiments, Trial, Variation}
  alias ExampleApp.Repo

  test "shows anytime-valid p-values and lift sequences for each treatment versus control", %{
    conn: conn
  } do
    {:ok, experiment} =
      Experiments.upsert_experiment_and_update_weights(
        "significance_results",
        "Significance results",
        [{"control", 1.0}, {"treatment_a", 1.0}, {"treatment_b", 1.0}],
        success1_label: "Signup"
      )

    insert_trials(experiment, "control", 500, 50)
    insert_trials(experiment, "treatment_a", 500, 100)
    insert_trials(experiment, "treatment_b", 500, 175)

    {:ok, view, _html} = live(conn, "/admin/ex_abby/#{experiment.id}")

    assert has_element?(view, "th", "P vs control")
    assert has_element?(view, "td", "Control")
    assert has_element?(view, "td span", "0.110")
    assert has_element?(view, "td.p-value-significant span", "< 0.001")

    assert has_element?(
             view,
             "td.p-value-significant small span",
             "+25.0% [+12.9%, +36.5%]"
           )

    assert has_element?(
             view,
             "td.p-value-significant svg.sig-chart-significant title",
             "Lift +25.0%; 95% interval +12.9% to +36.5%"
           )

    html = render(view)
    assert html =~ "Anytime-valid p-values compare each treatment with"
    assert html =~ "Negative means the treatment converted worse than"
    assert html =~ "<strong>control</strong>"
  end

  test "warns instead of comparing when no variation matches the configured control name", %{
    conn: conn
  } do
    {:ok, experiment} =
      Experiments.upsert_experiment_and_update_weights(
        "significance_no_control",
        "Significance without a control",
        [{"baseline", 1.0}, {"treatment", 1.0}],
        success1_label: "Signup"
      )

    insert_trials(experiment, "baseline", 200, 20)
    insert_trials(experiment, "treatment", 200, 60)

    {:ok, view, _html} = live(conn, "/admin/ex_abby/#{experiment.id}")

    assert has_element?(view, "p.significance-warning")
    assert render(view) =~ "Significance is unavailable because this experiment has no variation"
    assert has_element?(view, "td.p-value-unavailable span", "—")
    refute has_element?(view, "td.p-value-significant")
  end

  test "reports insufficient data for a treatment with no eligible trials", %{conn: conn} do
    {:ok, experiment} =
      Experiments.upsert_experiment_and_update_weights(
        "significance_sparse",
        "Significance with an empty arm",
        [{"control", 1.0}, {"treatment_a", 1.0}, {"empty_arm", 0.0}],
        success1_label: "Signup"
      )

    insert_trials(experiment, "control", 500, 50)
    insert_trials(experiment, "treatment_a", 500, 175)

    {:ok, view, _html} = live(conn, "/admin/ex_abby/#{experiment.id}")

    assert has_element?(view, "td.p-value-unavailable span", "No data")

    # The empty arm still consumes a Holm comparison, so treatment_a is adjusted
    # against a family of two rather than one.
    assert has_element?(view, "td.p-value-significant span", "< 0.001")
  end

  test "jointly corrects both success metrics while allowing either one to win", %{conn: conn} do
    {:ok, experiment} =
      Experiments.upsert_experiment_and_update_weights(
        "significance_multiple_metrics",
        "Significance across multiple metrics",
        [{"control", 1.0}, {"treatment", 1.0}],
        success1_label: "Signup",
        success2_label: "Purchase"
      )

    insert_trials(experiment, "control", 1_000, 100, 100)
    insert_trials(experiment, "treatment", 1_000, 100, 185)

    {:ok, view, _html} = live(conn, "/admin/ex_abby/#{experiment.id}")

    assert has_element?(view, "td.p-value-significant span", "0.025")
    assert has_element?(view, "td span", "1.000")

    html = render(view)
    assert html =~ "Either success metric can be highlighted; both"
    assert html =~ "do not need to be significant."
  end

  defp insert_trials(
         experiment,
         variation_name,
         count,
         success1_conversion_count,
         success2_conversion_count \\ 0
       ) do
    variation =
      Repo.one!(
        from(v in Variation,
          where: v.experiment_id == ^experiment.id and v.name == ^variation_name
        )
      )

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    timestamp = DateTime.to_naive(now)

    rows =
      for index <- 1..count do
        success1? = index <= success1_conversion_count
        success2? = index <= success2_conversion_count

        %{
          experiment_id: experiment.id,
          variation_id: variation.id,
          session_id: "#{variation_name}-#{index}",
          success1_count: if(success1?, do: 1, else: 0),
          success1_date: if(success1?, do: now, else: nil),
          success2_count: if(success2?, do: 1, else: 0),
          success2_date: if(success2?, do: now, else: nil),
          inserted_at: timestamp,
          updated_at: timestamp
        }
      end

    assert {^count, nil} = Repo.insert_all(Trial, rows)
  end
end
