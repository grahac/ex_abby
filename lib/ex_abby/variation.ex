defmodule ExAbby.Variation do
  @moduledoc """
  Schema: exabby_variations
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "exabby_variations" do
    belongs_to(:experiment, ExAbby.Experiment)
    field(:name, :string)
    field(:weight, :float, default: 1.0)
    timestamps()
  end

  def changeset(variation, attrs) do
    variation
    |> cast(attrs, [:experiment_id, :name, :weight])
    |> validate_required([:experiment_id, :name, :weight])
    |> validate_number(:weight, greater_than_or_equal_to: 0)
  end
end
