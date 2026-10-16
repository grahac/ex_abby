defmodule ExAbby.Live.TrialManagementLiveTest do
  use ExUnit.Case, async: true

  alias ExAbby.{Trial, Variation}
  alias ExAbby.Live.TrialManagementLive

  defmodule TestRouter do
    use Phoenix.Router
    import ExAbby.Router

    scope "/admin" do
      ex_abby_admin_routes()
    end

    scope "/" do
      ex_abby_trials_route()
    end
  end

  @session_trial %Trial{id: 1, experiment_id: 10, session_id: "browser-a", user_id: nil}
  @user_trial %Trial{id: 2, experiment_id: 10, session_id: nil, user_id: 42}
  @same_experiment %Variation{id: 100, experiment_id: 10}
  @other_experiment %Variation{id: 200, experiment_id: 20}

  defp viewer(attrs), do: Map.merge(%{admin?: false, session_id: nil, user_id: nil}, attrs)

  test "a visitor may move their own session trial" do
    assert TrialManagementLive.update_allowed?(
             @session_trial,
             @same_experiment,
             viewer(%{session_id: "browser-a"})
           )
  end

  test "a signed-in visitor may move their own user trial" do
    assert TrialManagementLive.update_allowed?(
             @user_trial,
             @same_experiment,
             viewer(%{user_id: 42})
           )
  end

  test "a visitor may not move someone else's trial by sending its id" do
    refute TrialManagementLive.update_allowed?(
             @session_trial,
             @same_experiment,
             viewer(%{session_id: "browser-b"})
           )

    refute TrialManagementLive.update_allowed?(
             @user_trial,
             @same_experiment,
             viewer(%{user_id: 7})
           )

    refute TrialManagementLive.update_allowed?(@session_trial, @same_experiment, viewer(%{}))
  end

  test "the admin mount may move any trial" do
    assert TrialManagementLive.update_allowed?(
             @user_trial,
             @same_experiment,
             viewer(%{admin?: true})
           )
  end

  test "nobody may move a trial to another experiment's variation, or a missing one" do
    refute TrialManagementLive.update_allowed?(
             @session_trial,
             @other_experiment,
             viewer(%{admin?: true})
           )

    refute TrialManagementLive.update_allowed?(nil, @same_experiment, viewer(%{admin?: true}))

    refute TrialManagementLive.update_allowed?(
             @session_trial,
             nil,
             viewer(%{session_id: "browser-a"})
           )
  end

  test "only the admin routes mount the trials page with admin powers" do
    assert %{phoenix_live_view: {TrialManagementLive, :admin, _opts, _extra}} =
             Phoenix.Router.route_info(TestRouter, "GET", "/admin/ex_abby/trials", "localhost")

    assert %{phoenix_live_view: {TrialManagementLive, nil, _opts, _extra}} =
             Phoenix.Router.route_info(TestRouter, "GET", "/ex_abby/trials", "localhost")
  end
end
