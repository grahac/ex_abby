defmodule ExAbby.SessionPlug do
  @moduledoc """
  A Plug that ensures each user has an ex_abby_session_id and compact bot
  status in their session. This is helpful so that LiveViews also have a
  stable session ID and request eligibility status to use when assigning an
  experiment variation.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    session_id = get_session(conn, "ex_abby_session_id")

    conn =
      if session_id do
        conn
      else
        conn
        |> put_session("ex_abby_session_id", generate_session_id())
      end

    bot_status = ExAbby.BotDetector.detect(conn)

    conn = assign(conn, :ex_abby_bot, bot_status)

    if get_session(conn, "ex_abby_bot") == bot_status do
      conn
    else
      put_session(conn, "ex_abby_bot", bot_status)
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
