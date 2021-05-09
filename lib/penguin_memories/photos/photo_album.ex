defmodule PenguinMemories.Photos.PhotoAlbum do
  @moduledoc """
  A relationship between a photo and an album.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.Photo

  @timestamps_opts [type: :utc_datetime]

  @type t :: %__MODULE__{
          id: integer | nil,
          photo_id: integer | nil,
          photo: Photo.t() | Ecto.Association.NotLoaded.t() | nil,
          album_id: integer | nil,
          album: Album.t() | Ecto.Association.NotLoaded.t() | nil
        }

  schema "pm_photo_album" do
    belongs_to :photo, PenguinMemories.Photos.Photo
    belongs_to :album, PenguinMemories.Photos.Album
    timestamps()
  end

  def changeset(photo_album, attrs) do
    photo_album
    |> cast(attrs, [:photo_id, :album_id])
    |> validate_required([:photo_id, :album_id])
    |> foreign_key_constraint(:photo_id, name: :photo_id_refs_photo_id_56180e95)
    |> foreign_key_constraint(:album_id, name: :album_id_refs_album_id_58ff3a98)
  end
end
