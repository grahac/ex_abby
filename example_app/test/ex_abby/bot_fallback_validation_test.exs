defmodule ExampleApp.ExAbbyBotFallbackValidationTest do
  use ExampleApp.DataCase

  import Plug.Conn
  import Plug.Test

  alias ExAbby.{Experiments, Trial}
  alias ExampleApp.Repo

  setup do
    original_config = Application.get_env(:ex_abby, :bot_detection, :missing)

    on_exit(fn ->
      case original_config do
        :missing -> Application.delete_env(:ex_abby, :bot_detection)
        config -> Application.put_env(:ex_abby, :bot_detection, config)
      end
    end)

    :ok
  end

  test "bots assign the fallback only for active experiments that define it" do
    active = setup_experiment("active_bot_fallback")
    archived = setup_experiment("archived_bot_fallback")
    assert {:ok, _experiment} = Experiments.archive_experiment(archived.id)

    Application.put_env(:ex_abby, :bot_detection, fallback_variation: "control")
    attach_excluded_assignment_handler()

    requested_experiments = [active.name, "missing_bot_fallback", archived.name]

    conn =
      conn(:get, "/")
      |> init_test_session(%{"ex_abby_session_id" => "controller-validation-bot"})
      |> assign(:ex_abby_bot, {:bot, :googlebot})

    {conn, variations} =
      ExAbby.PhoenixHelper.get_session_exp_variations(conn, requested_experiments)

    assert variations == %{active.name => "control"}
    assert conn.assigns.ex_abby_trials == %{active.name => "control"}
    assert_receive {:excluded_assignment, %{experiment: active_name, bot_name: :googlebot}}
    assert active_name == active.name
    refute_receive {:excluded_assignment, _}

    socket =
      ExAbby.LiveViewHelper.fetch_session_exp_variations_lv(
        %Phoenix.LiveView.Socket{},
        %{
          "ex_abby_session_id" => "liveview-validation-bot",
          "ex_abby_bot" => {:bot, :gptbot}
        },
        requested_experiments
      )

    assert socket.assigns.ex_abby_trials == %{active.name => "control"}
    assert_receive {:excluded_assignment, %{experiment: live_active_name, bot_name: :gptbot}}
    assert live_active_name == active.name
    refute_receive {:excluded_assignment, _}

    assert Repo.aggregate(Trial, :count) == 0
  end

  test "bots omit active experiments when the configured fallback is absent" do
    experiment = setup_experiment("invalid_bot_fallback")

    Application.put_env(:ex_abby, :bot_detection, fallback_variation: "not-a-variation")
    attach_excluded_assignment_handler()

    conn =
      conn(:get, "/")
      |> init_test_session(%{"ex_abby_session_id" => "controller-invalid-fallback-bot"})
      |> assign(:ex_abby_bot, {:bot, :googlebot})

    {conn, variations} =
      ExAbby.PhoenixHelper.get_session_exp_variations(conn, [experiment.name])

    assert variations == %{}
    assert conn.assigns.ex_abby_trials == %{}
    refute_receive {:excluded_assignment, _}

    socket =
      ExAbby.LiveViewHelper.fetch_session_exp_variations_lv(
        %Phoenix.LiveView.Socket{},
        %{
          "ex_abby_session_id" => "liveview-invalid-fallback-bot",
          "ex_abby_bot" => {:bot, :gptbot}
        },
        [experiment.name]
      )

    assert socket.assigns.ex_abby_trials == %{}
    refute_receive {:excluded_assignment, _}
    assert Repo.aggregate(Trial, :count) == 0
  end

  defp setup_experiment(name) do
    assert {:ok, _experiment} =
             Experiments.upsert_experiment_and_update_weights(name, "desc", [
               {"control", 1.0},
               {"treatment", 1.0}
             ])

    Experiments.get_experiment_by_name(name)
  end

  defp attach_excluded_assignment_handler do
    telemetry_id = "bot-fallback-validation-#{System.unique_integer([:positive])}"

    assert :ok =
             :telemetry.attach(
               telemetry_id,
               [:ex_abby, :assignment, :excluded],
               fn _event, _measurements, metadata, pid ->
                 send(pid, {:excluded_assignment, metadata})
               end,
               self()
             )

    on_exit(fn -> :telemetry.detach(telemetry_id) end)
  end
end
