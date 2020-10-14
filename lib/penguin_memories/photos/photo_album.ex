defmodule PenguinMemories.Photos.PhotoAlbum do
  @moduledoc """
  A relationship between a photo and an album.
  """

  use Ecto.Schema

  schema "spud_photo_album" do
    belongs_to :photo, PenguinMemories.Photos.Photo
    belongs_to :album, PenguinMemories.Photos.Album
  end
end
