defmodule ExAbby.AdminStyleTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias ExAbby.Experiment
  alias ExAbby.Live.{AdminStyle, ExperimentIndexLive, ExperimentShowLive, TrialManagementLive}

  test "shared admin styles expose the accessible Seline palette as semantic tokens" do
    html = render(&AdminStyle.styles/1, %{})

    assert html =~ "--ex-abby-color-canvas: #fafaf9"
    assert html =~ "--ex-abby-color-surface: #ffffff"
    assert html =~ "--ex-abby-color-ink: #0c0a09"
    assert html =~ "--ex-abby-color-signal-blue: #3ba6f1"
    assert html =~ "--ex-abby-color-accent: #2563eb"
    assert html =~ "--ex-abby-color-success: #047857"
    assert html =~ "--ex-abby-color-warning: #92400e"
    assert html =~ "--ex-abby-color-danger: #c81e1e"
    assert html =~ ":focus-visible"
    assert html =~ "outline: 2px solid var(--ex-abby-color-stone-charcoal)"
    assert html =~ "color: var(--ex-abby-color-ink)"
  end

  test "every admin screen renders inside the shared styled surface" do
    index_html =
      render(&ExperimentIndexLive.render/1, %{
        filter: :active,
        experiments: []
      })

    show_html =
      render(&ExperimentShowLive.render/1, %{
        experiment: %Experiment{
          id: 1,
          name: "Homepage",
          description: "Hero copy",
          variations: []
        },
        start_time: nil,
        end_time: nil,
        from_to_error_message: nil,
        winner_variation: nil,
        summary: [
          %{
            variation_id: 1,
            variation_name: "control",
            trials: 12,
            success1: %{count: 4, unique_count: 3, amount: 12.5, rate: 0.25},
            success2: %{count: 0, unique_count: 0, amount: 0.0, rate: 0.0}
          }
        ],
        weights_form: [{1, "control", 0.5}],
        control_variation_name: "control",
        success1_significance: {:error, :control_not_found},
        success2_significance: nil,
        success1_scale: nil,
        success2_scale: nil,
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
    assert show_html =~ "ex-abby-table-frame"
    assert show_html =~ "4 (3)"
    assert show_html =~ ~s(name="weights[weight_1]")
    assert trials_html =~ "ex-abby-panel"
  end

  defp render(component, assigns) do
    render_component(component, assigns)
  end
end
