defmodule MyApp.Repo.Migrations.ExAbbyBotExclusion do
  use Ecto.Migration

  def up, do: ExAbby.Migrations.v2_to_v3()
  def down, do: ExAbby.Migrations.v3_to_v2()
end
