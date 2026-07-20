defmodule ExAbby.BotDetector.Context do
  @moduledoc """
  Transient request data passed to bot detector modules.

  The context is created for a single classification and is never persisted by
  ExAbby. Custom detectors may use `conn` for host-provided request signals.
  """

  import Plug.Conn, only: [get_req_header: 2]

  @max_user_agent_bytes 4_096

  @type t :: %__MODULE__{
          user_agent: String.t(),
          conn: Plug.Conn.t() | nil
        }

  defstruct user_agent: "", conn: nil

  @doc false
  @spec new(String.t() | Plug.Conn.t() | t() | nil | term()) :: t()
  def new(%__MODULE__{} = context) do
    %{context | user_agent: normalize_user_agent(context.user_agent)}
  end

  def new(%Plug.Conn{} = conn) do
    %__MODULE__{
      user_agent: conn |> get_req_header("user-agent") |> List.first() |> normalize_user_agent(),
      conn: conn
    }
  end

  def new(user_agent) when is_binary(user_agent) do
    %__MODULE__{user_agent: normalize_user_agent(user_agent)}
  end

  def new(_input), do: %__MODULE__{}

  defp normalize_user_agent(user_agent) when is_binary(user_agent) do
    user_agent
    |> truncate_user_agent()
    |> valid_utf8_or_empty()
  end

  defp normalize_user_agent(_user_agent), do: ""

  defp truncate_user_agent(user_agent) when byte_size(user_agent) <= @max_user_agent_bytes,
    do: user_agent

  defp truncate_user_agent(user_agent), do: binary_part(user_agent, 0, @max_user_agent_bytes)

  defp valid_utf8_or_empty(user_agent) do
    if String.valid?(user_agent), do: user_agent, else: ""
  end
end
