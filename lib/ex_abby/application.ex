defmodule ExAbby.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # List any supervised processes for ExAbby here.
      # Typically, the ExAbby library might not start its own Repo or anything,
      # since that will come from the host app. We can leave this blank.
    ]

    opts = [strategy: :one_for_one, name: ExAbby.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
