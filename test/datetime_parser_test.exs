defmodule ExAbby.DatetimeParserTest do
  use ExUnit.Case, async: true

  alias ExAbby.DatetimeParser

  describe "parse/1" do
    test "handles nil" do
      assert DatetimeParser.parse(nil) == nil
    end

    test "handles 'now'" do
      assert {:ok, %DateTime{}} = DatetimeParser.parse("now")
    end

    test "handles relative dates" do
      assert {:ok, %DateTime{}} = DatetimeParser.parse("7 days ago")
      assert {:ok, %DateTime{}} = DatetimeParser.parse("1 week ago")
      assert {:ok, %DateTime{}} = DatetimeParser.parse("1 month ago")
      assert {:ok, %DateTime{}} = DatetimeParser.parse("1 year ago")
    end

    test "handles formatted dates" do
      assert {:ok, %DateTime{}} = DatetimeParser.parse("11/15/2025 3PM")
      assert {:ok, %DateTime{}} = DatetimeParser.parse("11/15/2025 3:00 PM")
    end

    test "handles invalid input" do
      assert DatetimeParser.parse("invalid") == nil
      assert DatetimeParser.parse("123") == nil
      assert DatetimeParser.parse("") == nil
    end
  end

  describe "timezone parsing" do
    setup do
      %{
        test_time: "01/29/2025 06:44PM",
        expected: %{hour: 18, minute: 44}
      }
    end

    for tz <- ~w(PST PDT EST EDT) do
      # bind the timezone to a module attribute
      @tz tz
      test "parses datetime with #{@tz} timezone", %{test_time: time, expected: expected} do
        case ExAbby.DatetimeParser.parse("#{time} #{@tz}") do
          {:ok, result} ->
            assert result.hour == expected.hour
            assert result.minute == expected.minute

          {:error, :utc_only_time_zone_database} ->
            IO.puts("\nSkipping timezone test - no timezone database configured")
            :ok
        end
      end
    end
  end
end
