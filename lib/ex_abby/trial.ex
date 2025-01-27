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
    field(:success1_amount, :float, default: 0.0)
    field(:success1_count, :integer, default: 0)
    field(:success1_date, :utc_datetime)
    field(:success2_amount, :float, default: 0.0)
    field(:success2_count, :integer, default: 0)
    field(:success2_date, :utc_datetime)
    timestamps()
  end

  def changeset(trial, attrs) do
    trial
    |> cast(attrs, [
      :experiment_id,
      :variation_id,
      :user_id,
      :session_id,
      :success1_amount,
      :success1_count,
      :success1_date,
      :success2_amount,
      :success2_count,
      :success2_date
    ])
    |> validate_required([:experiment_id, :variation_id])
    |> validate_number(:success1_count, greater_than_or_equal_to: 0)
    |> validate_number(:success2_count, greater_than_or_equal_to: 0)
    |> validate_number(:success1_amount, greater_than_or_equal_to: 0)
    |> validate_number(:success2_amount, greater_than_or_equal_to: 0)
  end
end
