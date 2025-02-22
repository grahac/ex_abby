defmodule ExAbby.Experiment do
  @moduledoc """
  Schema: ex_abby_experiments
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "ex_abby_experiments" do
    field(:name, :string)
    field(:description, :string)
    field(:success1_label, :string)
    field(:success2_label, :string)
    field(:start_time, :string)
    field(:end_time, :string)
    has_many(:variations, ExAbby.Variation)
    timestamps()
  end

  def changeset(experiment, attrs) do
    experiment
    |> cast(attrs, [:name, :description, :success1_label, :success2_label, :start_time, :end_time])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
