defmodule ExAbby.FunctionDispatchTest do
  use ExUnit.Case

  describe "function clause dispatching" do
    test "get_variations/2 dispatches correctly for integer user_id" do
      # We'll test that the function doesn't raise a FunctionClauseError
      # when called with an integer. The actual DB call will fail, but
      # that's expected without a configured repo.
      
      assert_raise RuntimeError, ~r/No Ecto repo configured/, fn ->
        ExAbby.get_variations(123, ["test_exp"])
      end
    end

    test "get_variation/2 dispatches correctly for integer user_id" do
      # Same test - we're checking that the function clause matches
      assert_raise RuntimeError, ~r/No Ecto repo configured/, fn ->
        ExAbby.get_variation(456, "test_exp")
      end
    end

    test "get_variations/2 still accepts user struct" do
      user = %{id: 789}
      assert_raise RuntimeError, ~r/No Ecto repo configured/, fn ->
        ExAbby.get_variations(user, ["test_exp"])
      end
    end

    test "get_variation/2 still accepts user struct" do
      user = %{id: 101}
      assert_raise RuntimeError, ~r/No Ecto repo configured/, fn ->
        ExAbby.get_variation(user, "test_exp")
      end
    end

    test "get_variations/2 accepts string for session-based experiments" do
      # Strings are now valid - they're treated as session IDs
      assert_raise RuntimeError, ~r/No Ecto repo configured/, fn ->
        ExAbby.get_variations("session_id_string", ["test_exp"])
      end
    end

    test "get_variation/2 accepts string for session-based experiments" do
      # Strings are now valid - they're treated as session IDs
      assert_raise RuntimeError, ~r/No Ecto repo configured/, fn ->
        ExAbby.get_variation("session_id_string", "test_exp")
      end
    end

    test "get_variations/2 raises FunctionClauseError for truly invalid input" do
      # Test with an atom or other non-supported type
      assert_raise FunctionClauseError, fn ->
        ExAbby.get_variations(:atom_input, ["test_exp"])
      end
    end

    test "get_variation/2 raises FunctionClauseError for truly invalid input" do
      assert_raise FunctionClauseError, fn ->
        ExAbby.get_variation(:atom_input, "test_exp")
      end
    end
  end
end