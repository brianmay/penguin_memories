defmodule PenguinMemories.Photos.PersonAscendant do
  @moduledoc "Index for persons"
  use Ecto.Schema
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime]

  @type t :: %__MODULE__{
          id: integer() | nil,
          position: integer() | nil,
          ascendant_id: integer() | nil,
          ascendant: t() | nil,
          descendant_id: integer() | nil,
          descendant: t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "pm_person_ascendant" do
    field :position, :integer
    belongs_to :ascendant, PenguinMemories.Photos.Person
    belongs_to :descendant, PenguinMemories.Photos.Person
    timestamps()
  end

  @doc false
  def changeset(person_ascendant, attrs) do
    person_ascendant
    |> cast(attrs, [:position])
    |> validate_required([:position])
  end
end
