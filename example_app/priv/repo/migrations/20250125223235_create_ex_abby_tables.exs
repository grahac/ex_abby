defmodule MyApp.Repo.Migrations.CreateExAbbyTables do
  use Ecto.Migration

  def up do
    # ExAbby.Migrations is your module that creates the tables
    ExAbby.Migrations.create_tables()
  end

  def down do
    ExAbby.Migrations.drop_tables()
  end
end
