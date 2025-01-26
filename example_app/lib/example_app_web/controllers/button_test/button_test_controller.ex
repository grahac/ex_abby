defmodule ExampleAppWeb.ButtonTest.ButtonTestController do
  use ExampleAppWeb, :controller

  def index(conn, _params) do
    {conn, variation} = ExAbby.get_variation(conn, "button_color_test")
    render(conn, :index, variation: variation)
  end

  def convert(conn, _params) do
    case ExAbby.record_success(conn, "button_color_test") do
      {:ok, _trial} ->
        conn
        |> put_flash(:info, "Conversion recorded!")
        |> redirect(to: ~p"/button-test")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Failed to record conversion")
        |> redirect(to: ~p"/button-test")
    end
  end
end
