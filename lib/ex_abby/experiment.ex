defmodule ExAbby.Experiment do
  @moduledoc """
  Schema: exabby_experiments
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "exabby_experiments" do
    field(:name, :string)
    field(:description, :string)
    field(:success1_label, :string)
    field(:success2_label, :string)

    has_many(:variations, ExAbby.Variation)
    timestamps()
  end

  def changeset(experiment, attrs) do
    experiment
    |> cast(attrs, [:name, :description, :success1_label, :success2_label])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
