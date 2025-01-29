defmodule ExAbby.DatetimeParser do
  @moduledoc """
  Handles parsing of various datetime formats including relative dates and formatted dates.
  """
  require Logger

  @doc """
  Parses a datetime string into a DateTime struct.
  Supports formats:
  - "now"
  - Relative dates: "7 days ago", "2 weeks ago", "1 month ago", "1 year ago"
  - Formatted dates: "11/15/2025 3PM" or "11/15/2025 3:00 PM"

  Returns nil if the string cannot be parsed.
  """
  def parse(nil), do: nil
  def parse("now"), do: {:ok, DateTime.utc_now()}

  def parse(datetime_str) when is_binary(datetime_str) do
    cond do
      String.contains?(datetime_str, "ago") ->
        case parse_relative_date(datetime_str) do
          nil -> nil
          result -> {:ok, result}
        end

      true ->
        parse_formatted_date(datetime_str)
    end
  rescue
    _ -> nil
  end

  @doc """
  Parses relative dates like "7 days ago"
  """
  def parse_relative_date(datetime_str) do
    case String.split(datetime_str) do
      [amount, unit, "ago"] ->
        case Integer.parse(amount) do
          {number, ""} -> subtract_time(number, unit)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Parses formatted dates like "11/15/2025 3PM" or "11/15/2025 3:00 PM"
  """

  def parse_formatted_date(datetime_str) do
    with {:ok, {normalized, timezone}} <- {:ok, normalize_time_format(datetime_str)},
         {:ok, naive_dt} <- NaiveDateTime.from_iso8601(normalized) do
      case DateTime.from_naive(naive_dt, timezone || "Etc/UTC") do
        {:ok, dt} ->
          if timezone do
            {:ok, DateTime.shift_zone!(dt, "Etc/UTC")}
          else
            {:ok, dt}
          end

        error ->
          error
      end
    else
      _error -> nil
    end
  end

  defp normalize_time_format(datetime_str) do
    # Extract timezone if present
    {datetime_str, timezone} = extract_timezone(datetime_str)
    datetime_str = Regex.replace(~r/(\d+(?::\d+)?)(AM|PM)/i, datetime_str, "\\1 \\2")

    case String.split(datetime_str, " ") do
      [date, time, period] ->
        date_parts = String.split(date, "/")
        month = String.pad_leading(Enum.at(date_parts, 0), 2, "0")
        day = String.pad_leading(Enum.at(date_parts, 1), 2, "0")
        year = List.last(date_parts)

        [hours | minutes] = String.split(time, ":")
        minutes = List.first(minutes, "00")
        hour = convert_12_to_24(hours, period)

        {
          "#{year}-#{month}-#{day}T#{hour}:#{minutes}:00",
          timezone
        }

      _error ->
        {datetime_str, timezone}
    end
  end

  defp extract_timezone(datetime_str) do
    cond do
      String.ends_with?(datetime_str, " UTC") ->
        {String.replace(datetime_str, " UTC", ""), "Etc/UTC"}

      String.ends_with?(datetime_str, " PST") ->
        {String.replace(datetime_str, " PST", ""), "America/Los_Angeles"}

      String.ends_with?(datetime_str, " PDT") ->
        {String.replace(datetime_str, " PDT", ""), "America/Los_Angeles"}

      String.ends_with?(datetime_str, " EST") ->
        {String.replace(datetime_str, " EST", ""), "America/New_York"}

      String.ends_with?(datetime_str, " EDT") ->
        {String.replace(datetime_str, " EDT", ""), "America/New_York"}

      true ->
        {datetime_str, nil}
    end
  end

  defp convert_12_to_24(hour_str, period) do
    hour = String.to_integer(hour_str)

    cond do
      period in ["PM", "pm"] and hour != 12 -> "#{hour + 12}"
      period in ["AM", "am"] and hour == 12 -> "00"
      true -> String.pad_leading("#{hour}", 2, "0")
    end
  end

  defp subtract_time(amount, unit) do
    case unit do
      unit when unit in ["minute", "minutes"] -> shift_time(amount, :minute)
      unit when unit in ["hour", "hours"] -> shift_time(amount, :hour)
      unit when unit in ["day", "days"] -> shift_time(amount, :day)
      unit when unit in ["week", "weeks"] -> shift_time(amount * 7, :day)
      unit when unit in ["month", "months"] -> shift_time(amount * 30, :day)
      unit when unit in ["year", "years"] -> shift_time(amount * 365, :day)
      _ -> nil
    end
  end

  defp shift_time(amount, :hour) do
    DateTime.utc_now()
    |> DateTime.add(-amount, :hour)
  end

  defp shift_time(amount, :minute) do
    DateTime.utc_now()
    |> DateTime.add(-amount, :minute)
  end

  defp shift_time(amount, :day) do
    DateTime.utc_now()
    |> DateTime.add(-amount, :day)
  end
end
