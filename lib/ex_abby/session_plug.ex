defmodule ExAbby.SessionPlug do
  @moduledoc """
  A Plug that ensures each user has an ex_abby_session_id in their session.
  This is helpful so that LiveViews also have a stable session ID to use
  when calling `get_session_exp_variation`.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    session_id = get_session(conn, "ex_abby_session_id")

    if session_id do
      conn
    else
      # generate a new ID and store it
      new_id = generate_session_id()

      conn
      |> put_session("ex_abby_session_id", new_id)
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
