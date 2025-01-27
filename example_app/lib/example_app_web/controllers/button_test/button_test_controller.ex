defmodule ExampleAppWeb.ButtonTest.ButtonTestController do
  use ExampleAppWeb, :controller

  def index(conn, _params) do
    # {conn, variation} = ExAbby.get_variation(conn, "button_color_test")
    {conn, _variations} = ExAbby.get_variations(conn, ["landing_page_test", "button_color_test"])

    render(conn, :index)
  end

  def convert(conn, %{"amount" => amount}) when not is_nil(amount) do
    case ExAbby.record_success(conn, "button_color_test", amount: amount, success_type: :success2) do
      {:ok, _trial} ->
        conn
        |> put_flash(:info, "Conversion with $#{amount} recorded!")
        |> redirect(to: ~p"/button-test")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Failed to record conversion")
        |> redirect(to: ~p"/button-test")
    end
  end

  def convert(conn, _params) do
    case ExAbby.record_successes(conn,  ["landing_page_test", "button_color_test"]) do
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
