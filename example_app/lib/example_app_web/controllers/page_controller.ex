defmodule ExampleAppWeb.PageController do
  use ExampleAppWeb, :controller

  def redirect_to_home(conn, _params) do
    redirect(conn, to: "/")
  end

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end
end
