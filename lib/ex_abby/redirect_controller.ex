defmodule ExAbby.RedirectController do
  use Phoenix.Controller

  def redirect_to_index(conn, _params) do
    redirect(conn, to: "/admin/ex_abby/index")
  end
end