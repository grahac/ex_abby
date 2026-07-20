defmodule ExAbby.SessionPlugTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  setup do
    original_config = Application.get_env(:ex_abby, :bot_detection, :missing)

    on_exit(fn ->
      case original_config do
        :missing -> Application.delete_env(:ex_abby, :bot_detection)
        config -> Application.put_env(:ex_abby, :bot_detection, config)
      end
    end)

    Application.delete_env(:ex_abby, :bot_detection)

    :ok
  end

  test "stores a compact bot status in assigns and session without request evidence" do
    user_agent = "Googlebot/2.1 (+https://www.google.com/bot.html)"

    conn =
      conn(:get, "/")
      |> init_test_session(%{})
      |> put_req_header("user-agent", user_agent)
      |> ExAbby.SessionPlug.call([])

    assert conn.assigns.ex_abby_bot == {:bot, :googlebot}
    assert get_session(conn, "ex_abby_bot") == {:bot, :googlebot}
    assert is_binary(get_session(conn, "ex_abby_session_id"))

    refute Map.has_key?(conn.assigns, :user_agent)
    refute Map.has_key?(conn.assigns, :remote_ip)
    refute user_agent in Map.values(get_session(conn))
  end

  test "re-evaluates status on each request while preserving an existing session id" do
    conn =
      conn(:get, "/")
      |> init_test_session(%{
        "ex_abby_session_id" => "existing-session",
        "ex_abby_bot" => {:bot, :googlebot}
      })
      |> put_req_header("user-agent", "Mozilla/5.0")
      |> ExAbby.SessionPlug.call([])

    assert conn.assigns.ex_abby_bot == :human
    assert get_session(conn, "ex_abby_bot") == :human
    assert get_session(conn, "ex_abby_session_id") == "existing-session"
  end
end
