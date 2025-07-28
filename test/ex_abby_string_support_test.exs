defmodule ExAbby.StringSupportTest do
  use ExUnit.Case

  describe "string support for session-based experiments" do
    test "get_variations/2 accepts string session_id" do
      # Test that it doesn't raise FunctionClauseError
      assert_raise RuntimeError, ~r/No Ecto repo configured/, fn ->
        ExAbby.get_variations("session123", ["exp1", "exp2"])
      end
    end

    test "get_variation/2 accepts string session_id" do
      assert_raise RuntimeError, ~r/No Ecto repo configured/, fn ->
        ExAbby.get_variation("session456", "test_exp")
      end
    end

    test "record_successes/3 accepts string session_id" do
      assert_raise RuntimeError, ~r/No Ecto repo configured/, fn ->
        ExAbby.record_successes("session789", ["exp1", "exp2"], [])
      end
    end

    test "record_success/3 accepts string session_id" do
      assert_raise RuntimeError, ~r/No Ecto repo configured/, fn ->
        ExAbby.record_success("session101", "test_exp", [])
      end
    end
  end
end