defmodule ExAbby.VariationAuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "exabby_variations_audit_log" do
    belongs_to(:variation, ExAbby.Variation)
    field(:previous_weight, :float)
    field(:new_weight, :float)
    field(:changed_by, :string)

    timestamps()
  end

  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:variation_id, :previous_weight, :new_weight, :changed_by])
    |> validate_required([:variation_id, :previous_weight, :new_weight])
    |> foreign_key_constraint(:variation_id)
  end
end
