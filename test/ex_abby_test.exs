defmodule ExAbbyTest do
  use ExUnit.Case
  doctest ExAbby

  test "greets the world" do
    assert ExAbby.hello() == :world
  end
end
