defmodule ExAbby.Trial do
  @moduledoc """
  Schema: exabby_trials
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "exabby_trials" do
    belongs_to(:experiment, ExAbby.Experiment)
    belongs_to(:variation, ExAbby.Variation)

    field(:user_id, :integer)
    field(:session_id, :string)
    field(:success_count, :integer, default: 0)
    field(:success_date, :utc_datetime)
    timestamps()
  end

  def changeset(trial, attrs) do
    trial
    |> cast(attrs, [
      :experiment_id,
      :variation_id,
      :user_id,
      :session_id,
      :success_count,
      :success_date
    ])
    |> validate_required([:experiment_id, :variation_id])
    |> validate_number(:success_count, greater_than_or_equal_to: 0)
  end
end
