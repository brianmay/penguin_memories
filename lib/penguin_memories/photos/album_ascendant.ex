defmodule PenguinMemories.Photos.AlbumAscendant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "spud_album_ascendant" do
    field :position, :integer
    belongs_to :ascendant, PenguinMemories.Photos.Album
    belongs_to :descendant, PenguinMemories.Photos.Album
  end

  @doc false
  def changeset(album_ascendant, attrs) do
    album_ascendant
    |> cast(attrs, [:position])
    |> validate_required([:position])
  end
end
