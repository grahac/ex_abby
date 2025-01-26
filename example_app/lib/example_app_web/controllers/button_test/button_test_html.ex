defmodule ExampleAppWeb.ButtonTest.ButtonTestHTML do
  use ExampleAppWeb, :html

  embed_templates "button_test_html/*"

  def get_button_class("blue"), do: "px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"

  def get_button_class("green"),
    do: "px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600"

  def get_button_class(_), do: "px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600"
end
