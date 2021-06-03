defmodule PenguinMemories.Photos.PlaceAscendant do
  @moduledoc "Index for places"
  use Ecto.Schema
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime_usec]

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

  schema "pm_place_ascendant" do
    field :position, :integer
    belongs_to :ascendant, PenguinMemories.Photos.Place
    belongs_to :descendant, PenguinMemories.Photos.Place
    timestamps()
  end

  @doc false
  def changeset(place_ascendant, attrs) do
    place_ascendant
    |> cast(attrs, [:position])
    |> validate_required([:position])
  end
end
