defmodule PenguinMemories.Photos.AlbumAscendant do
  @moduledoc "Index for albums"
  use Ecto.Schema
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime]

  @type t :: %__MODULE__{
          position: integer(),
          ascendant_id: integer(),
          ascendant: t(),
          descendant_id: integer(),
          descendant: t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "pm_album_ascendant" do
    field :position, :integer
    belongs_to :ascendant, PenguinMemories.Photos.Album
    belongs_to :descendant, PenguinMemories.Photos.Album
    timestamps()
  end

  @doc false
  def changeset(album_ascendant, attrs) do
    album_ascendant
    |> cast(attrs, [:position])
    |> validate_required([:position])
  end
end
