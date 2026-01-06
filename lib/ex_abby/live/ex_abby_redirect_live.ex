defmodule ExAbby.Live.ExAbbyRedirectLive do
  @moduledoc """
  Redirects /ex_abby to /ex_abby/index
  """
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: "ex_abby/index")}
  end

  def render(assigns) do
    ~H"""
    <div>Redirecting...</div>
    """
  end
end
