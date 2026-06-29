defmodule MyApp.Repo.Migrations.ExAbbyTrialUniqueness do
  use Ecto.Migration

  def up do
    ExAbby.Migrations.deduplicate_trials()
    ExAbby.Migrations.add_trial_uniqueness()
  end

  def down do
    ExAbby.Migrations.remove_trial_uniqueness()
  end
end
