defmodule ExampleAppWeb.ButtonTestLive do
  use ExampleAppWeb, :live_view

  def mount(_params, session, socket) do
    socket = ExAbby.get_variations(socket, session, ["landing_page_test", "button_color_test"])

    {:ok, assign(socket, session: session)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-md text-blue-900 mx-auto mt-10 p-6 bg-white rounded-lg shadow-lg">
      <h1 class="text-2xl font-bold mb-4">Landing Page Test</h1>
      <%= case @ex_abby_trials["landing_page_test"] do %>
        <% "hello_world" -> %>
          <div>Hello World!</div>
        <% _ -> %>
          <div>This is the control</div>
      <% end %>
      <div class="border-t border-gray-300 my-6"></div>

      <h1 class="text-2xl font-bold mb-4">Button Color Test</h1>

      <%= if @ex_abby_trials["button_color_test"] do %>
        <div class="space-y-4">
          <button phx-click="convert" class={get_button_class(@ex_abby_trials["button_color_test"])}>
            Click Me!
          </button>

          <button
            phx-click="convert_with_amount"
            class={get_button_class(@ex_abby_trials["button_color_test"])}
          >
            Click for $100!
          </button>

          <p class="mt-4 text-gray-600">Current variation: {@ex_abby_trials["button_color_test"]}</p>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("convert", _params, socket) do
    case ExAbby.record_successes(socket, ["landing_page_test", "button_color_test"]) do
      {:ok, _trial} ->
        {:noreply, put_flash(socket, :info, "Conversion recorded!")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to record conversion")}
    end
  end

  def handle_event("convert_with_amount", _params, socket) do
    case ExAbby.record_success(socket, "button_color_test",
           amount: 100.0,
           success_type: :success2
         ) do
      {:ok, _trial} ->
        {:noreply, put_flash(socket, :info, "Conversion with $100 recorded!")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to record conversion")}
    end
  end

  defp get_button_class("blue"), do: "px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"

  defp get_button_class("green"),
    do: "px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600"

  defp get_button_class(_), do: "px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600"
end
