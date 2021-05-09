defmodule PenguinMemories.Photos.PlaceAscendant do
  @moduledoc "Index for albums"
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

  schema "pm_album_ascendant" do
    field :position, :integer
    belongs_to :ascendant, PenguinMemories.Photos.Place
    belongs_to :descendant, PenguinMemories.Photos.Place
    timestamps()
  end

  @doc false
  def changeset(album_ascendant, attrs) do
    album_ascendant
    |> cast(attrs, [:position])
    |> validate_required([:position])
  end
end
