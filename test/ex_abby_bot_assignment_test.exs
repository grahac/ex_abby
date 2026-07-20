defmodule ExAbby.BotAssignmentTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias ExAbby.{Experiment, Variation}

  defmodule ValidatingRepo do
    @moduledoc false

    def one(%Ecto.Query{joins: []}), do: %Experiment{id: 1, name: "pricing", archived_at: nil}

    def one(%Ecto.Query{wheres: wheres}) do
      variation_name =
        wheres
        |> Enum.flat_map(& &1.params)
        |> Enum.map(&elem(&1, 0))
        |> List.last()

      %Variation{id: 1, experiment_id: 1, name: variation_name}
    end
  end

  setup do
    original_config = Application.get_env(:ex_abby, :bot_detection, :missing)
    original_repo = Application.get_env(:ex_abby, :repo, :missing)

    on_exit(fn ->
      case original_config do
        :missing -> Application.delete_env(:ex_abby, :bot_detection)
        config -> Application.put_env(:ex_abby, :bot_detection, config)
      end

      case original_repo do
        :missing -> Application.delete_env(:ex_abby, :repo)
        repo -> Application.put_env(:ex_abby, :repo, repo)
      end
    end)

    Application.put_env(:ex_abby, :repo, ValidatingRepo)

    :ok
  end

  test "controller assignments give bots the configured fallback after validating persistence" do
    telemetry_id = "ex-abby-bot-assignment-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        telemetry_id,
        [:ex_abby, :assignment, :excluded],
        fn event, measurements, metadata, pid ->
          send(pid, {:excluded_assignment, event, measurements, metadata})
        end,
        self()
      )

    on_exit(fn -> :telemetry.detach(telemetry_id) end)

    Application.put_env(:ex_abby, :bot_detection, fallback_variation: "baseline")

    conn =
      conn(:get, "/")
      |> init_test_session(%{
        "ex_abby_session_id" => "bot-session",
        "ex_abby_bot" => {:bot, :googlebot}
      })
      |> assign(:ex_abby_bot, {:bot, :googlebot})

    {conn, variations} = ExAbby.PhoenixHelper.get_session_exp_variations(conn, ["pricing"])

    assert variations == %{"pricing" => "baseline"}
    assert conn.assigns.ex_abby_trials == %{"pricing" => "baseline"}

    assert_receive {:excluded_assignment, [:ex_abby, :assignment, :excluded], %{}, metadata}
    assert metadata == %{experiment: "pricing", reason: :bot, bot_name: :googlebot}
  end

  test "LiveView reads bot status directly from its mount session and skips persistence" do
    socket =
      ExAbby.LiveViewHelper.fetch_session_exp_variations_lv(
        %Phoenix.LiveView.Socket{},
        %{
          "ex_abby_session_id" => "bot-session",
          "ex_abby_bot" => {:bot, :gptbot}
        },
        ["pricing"]
      )

    assert socket.assigns.ex_abby_bot == {:bot, :gptbot}
    assert socket.assigns.ex_abby_trials == %{"pricing" => "control"}
  end
end
