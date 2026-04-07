defmodule ExAbby.Live.ExAbbyRedirectLive do
  @moduledoc """
  Redirects /ex_abby to /ex_abby/index
  """
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(_params, uri, socket) do
    %URI{path: path} = URI.parse(uri)
    {:noreply, push_navigate(socket, to: "#{path}/index")}
  end

  def render(assigns) do
    ~H"""
    <div>Redirecting...</div>
    """
  end
end
