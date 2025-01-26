# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     ExampleApp.Repo.insert!(%ExampleApp.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Add to your existing seeds.exs
Code.require_file("seeds/experiments.exs", __DIR__)
