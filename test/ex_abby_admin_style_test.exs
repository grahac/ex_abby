defmodule ExAbby.AdminStyleTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias ExAbby.{Experiment, ExperimentReport, Variation}
  alias ExAbby.Live.{AdminStyle, ExperimentIndexLive, ExperimentShowLive, TrialManagementLive}

  test "shared admin styles expose the accessible Seline palette as semantic tokens" do
    html = render(&AdminStyle.styles/1, %{})

    assert html =~ "--ex-abby-color-canvas: #f7f6f3"
    assert html =~ "--ex-abby-color-surface: #ffffff"
    assert html =~ "--ex-abby-color-ink: #191a17"
    assert html =~ "--ex-abby-color-accent: #12664a"
    assert html =~ "--ex-abby-color-success: #12664a"
    assert html =~ "--ex-abby-color-warning: #8a6a18"
    assert html =~ "--ex-abby-color-danger: #a33a2a"
    assert html =~ ":focus-visible"
    assert html =~ "outline: 2px solid var(--ex-abby-color-ink)"
    assert html =~ "color: var(--ex-abby-color-ink)"
  end

  test "every admin screen renders inside the shared styled surface" do
    index_html =
      render(&ExperimentIndexLive.render/1, %{
        filter: :active,
        query: "",
        reports: [],
        archived: [],
        counts: %{running: 0, significant: 0, archived: 0},
        scale: 1.0
      })

    show_report =
      ExperimentReport.from_summary(
        %Experiment{
          id: 1,
          name: "Homepage",
          description: "Hero copy",
          inserted_at: ~N[2026-08-01 00:00:00],
          variations: [
            %Variation{id: 1, name: "control", weight: 0.5},
            %Variation{id: 2, name: "bold", weight: 0.5}
          ]
        },
        [
          %{
            variation_id: 1,
            variation_name: "control",
            trials: 12,
            excluded_trials: 0,
            success1: %{
              count: 4,
              unique_count: 3,
              amount: 12.5,
              rate: 0.25,
              amount_per_trial: 1.0
            },
            success2: %{count: 0, unique_count: 0, amount: 0.0, rate: 0.0, amount_per_trial: 0.0}
          },
          %{
            variation_id: 2,
            variation_name: "bold",
            trials: 12,
            excluded_trials: 0,
            success1: %{
              count: 5,
              unique_count: 5,
              amount: 20.0,
              rate: 0.42,
              amount_per_trial: 1.0
            },
            success2: %{count: 0, unique_count: 0, amount: 0.0, rate: 0.0, amount_per_trial: 0.0}
          }
        ],
        DateTime.utc_now()
      )

    show_html =
      render(&ExperimentShowLive.render/1, %{
        report: show_report,
        experiment: show_report.experiment,
        start_time: nil,
        end_time: nil,
        from_to_error_message: nil,
        updated?: false
      })

    trials_html =
      render(&TrialManagementLive.render/1, %{
        standalone: false,
        user_trials_expanded: true,
        session_trials_expanded: true,
        user_id: nil,
        ex_abby_session_id: "session-1",
        user_experiments: [],
        session_experiments: []
      })

    for html <- [index_html, show_html, trials_html] do
      assert html =~ ~s(class="ex-abby-admin")
      assert html =~ "ex-abby-admin__shell"
    end

    assert index_html =~ "ex-abby-table-frame"
    assert show_html =~ "Allocation"
    assert show_html =~ "baseline"
    assert show_html =~ "Σ 1.00"
    assert show_html =~ "ahead on" or show_html =~ "No significant difference yet."
    assert show_html =~ ~s(name="weights[weight_1]")
    assert show_html =~ ~s(data-phx-link="redirect")
    assert show_html =~ ~s(for="ex-abby-winner-variation")
    assert show_html =~ ~s(id="ex-abby-winner-variation")
    assert trials_html =~ "ex-abby-panel"
    assert trials_html =~ ~s(data-phx-link="redirect")
    assert trials_html =~ ~s(aria-expanded="true")
  end

  defp render(component, assigns) do
    render_component(component, assigns)
  end
end
