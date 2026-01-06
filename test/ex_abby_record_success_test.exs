defmodule ExAbby.RecordSuccessTest do
  use ExUnit.Case

  alias ExAbby.Experiments

  setup_all do
    {:module, _} = Code.ensure_compiled(ExAbby)
    {:module, _} = Code.ensure_compiled(ExAbby.Experiments)
    {:module, _} = Code.ensure_compiled(ExAbby.PhoenixHelper)
    {:module, _} = Code.ensure_compiled(ExAbby.LiveViewHelper)
    :ok
  end

  describe "ExAbby.record_successes/3 - function signatures" do
    test "record_successes/2 exists (with default opts)" do
      functions = ExAbby.__info__(:functions)
      assert {:record_successes, 2} in functions
    end

    test "record_successes/3 exists" do
      functions = ExAbby.__info__(:functions)
      assert {:record_successes, 3} in functions
    end

    test "record_success/2 exists (single experiment with default opts)" do
      functions = ExAbby.__info__(:functions)
      assert {:record_success, 2} in functions
    end

    test "record_success/3 exists (single experiment)" do
      functions = ExAbby.__info__(:functions)
      assert {:record_success, 3} in functions
    end
  end

  describe "Experiments module - session success functions" do
    test "record_success_for_session/2 exists (with default opts)" do
      functions = Experiments.__info__(:functions)
      assert {:record_success_for_session, 2} in functions
    end

    test "record_success_for_session/3 exists" do
      functions = Experiments.__info__(:functions)
      assert {:record_success_for_session, 3} in functions
    end

    test "record_session_successes/2 exists (with default opts)" do
      functions = Experiments.__info__(:functions)
      assert {:record_session_successes, 2} in functions
    end

    test "record_session_successes/3 exists" do
      functions = Experiments.__info__(:functions)
      assert {:record_session_successes, 3} in functions
    end
  end

  describe "Experiments module - user success functions (should match session)" do
    test "record_success_for_user/2 exists (with default opts)" do
      functions = Experiments.__info__(:functions)
      assert {:record_success_for_user, 2} in functions
    end

    test "record_success_for_user/3 exists" do
      functions = Experiments.__info__(:functions)
      assert {:record_success_for_user, 3} in functions
    end

    test "record_user_successes/2 exists (with default opts)" do
      functions = Experiments.__info__(:functions)
      assert {:record_user_successes, 2} in functions
    end

    test "record_user_successes/3 exists" do
      functions = Experiments.__info__(:functions)
      assert {:record_user_successes, 3} in functions
    end
  end

  describe "PhoenixHelper - session success functions" do
    test "record_success_for_session/2 exists" do
      functions = ExAbby.PhoenixHelper.__info__(:functions)
      assert {:record_success_for_session, 2} in functions
    end

    test "record_success_for_session/3 exists" do
      functions = ExAbby.PhoenixHelper.__info__(:functions)
      assert {:record_success_for_session, 3} in functions
    end

    test "record_success_for_session_id/2 exists" do
      functions = ExAbby.PhoenixHelper.__info__(:functions)
      assert {:record_success_for_session_id, 2} in functions
    end

    test "record_success_for_session_id/3 exists" do
      functions = ExAbby.PhoenixHelper.__info__(:functions)
      assert {:record_success_for_session_id, 3} in functions
    end

    test "record_successes_for_session/2 exists" do
      functions = ExAbby.PhoenixHelper.__info__(:functions)
      assert {:record_successes_for_session, 2} in functions
    end

    test "record_successes_for_session/3 exists" do
      functions = ExAbby.PhoenixHelper.__info__(:functions)
      assert {:record_successes_for_session, 3} in functions
    end

    test "record_successes_for_session_id/2 exists" do
      functions = ExAbby.PhoenixHelper.__info__(:functions)
      assert {:record_successes_for_session_id, 2} in functions
    end

    test "record_successes_for_session_id/3 exists" do
      functions = ExAbby.PhoenixHelper.__info__(:functions)
      assert {:record_successes_for_session_id, 3} in functions
    end
  end

  describe "LiveViewHelper - session success functions" do
    test "record_success_for_session_lv/2 exists" do
      functions = ExAbby.LiveViewHelper.__info__(:functions)
      assert {:record_success_for_session_lv, 2} in functions
    end

    test "record_success_for_session_lv/3 exists" do
      functions = ExAbby.LiveViewHelper.__info__(:functions)
      assert {:record_success_for_session_lv, 3} in functions
    end

    test "record_successes_for_session_lv/2 exists" do
      functions = ExAbby.LiveViewHelper.__info__(:functions)
      assert {:record_successes_for_session_lv, 2} in functions
    end

    test "record_successes_for_session_lv/3 exists" do
      functions = ExAbby.LiveViewHelper.__info__(:functions)
      assert {:record_successes_for_session_lv, 3} in functions
    end
  end

  describe "Trial retrieval functions - should exist for both session and user" do
    test "get_trial_by_session/2 exists" do
      functions = Experiments.__info__(:functions)
      assert {:get_trial_by_session, 2} in functions
    end

    test "get_trial_by_user/2 exists" do
      functions = Experiments.__info__(:functions)
      assert {:get_trial_by_user, 2} in functions
    end
  end

  describe "record_success/2 core function" do
    test "record_success/2 exists in Experiments module" do
      functions = Experiments.__info__(:functions)
      assert {:record_success, 2} in functions
    end
  end
end
