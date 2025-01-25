defmodule ExAbby.Experiment do
  @moduledoc """
  Schema: exabby_experiments
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "exabby_experiments" do
    field(:name, :string)
    field(:description, :string)
    has_many(:variations, ExAbby.Variation)
    timestamps()
  end

  def changeset(experiment, attrs) do
    experiment
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
