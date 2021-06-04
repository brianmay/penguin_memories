defmodule PenguinMemories.Photos.PhotoAlbum do
  @moduledoc """
  A relationship between a photo and an album.
  """

  use Ecto.Schema

  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.Photo

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: integer | nil,
          photo_id: integer | nil,
          photo: Photo.t() | Ecto.Association.NotLoaded.t() | nil,
          album_id: integer | nil,
          album: Album.t() | Ecto.Association.NotLoaded.t() | nil
        }

  schema "pm_photo_album" do
    belongs_to :photo, Photo
    belongs_to :album, Album
    timestamps()
  end
end
