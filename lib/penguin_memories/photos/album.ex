defmodule PenguinMemories.Photos.Album do
  @moduledoc "An album containing photos and subalbums"
  use Ecto.Schema

  alias PenguinMemories.Photos.AlbumAscendant
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.PhotoAlbum

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: integer() | nil,
          cover_photo_id: integer() | nil,
          cover_photo: Photo.t() | Ecto.Association.NotLoaded.t(),
          name: String.t() | nil,
          description: String.t() | nil,
          private_notes: String.t() | nil,
          revised: DateTime.t() | nil,
          parent_id: integer() | nil,
          parent: t() | Ecto.Association.NotLoaded.t() | nil,
          children: list(t()) | Ecto.Association.NotLoaded.t(),
          ascendants: list(AlbumAscendant.t()) | Ecto.Association.NotLoaded.t(),
          descendants: list(AlbumAscendant.t()) | Ecto.Association.NotLoaded.t(),
          photos: list(Photo.t()) | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "pm_album" do
    belongs_to :cover_photo, Photo, on_replace: :nilify
    field :name, :string
    field :description, :string
    field :private_notes, :string
    field :revised, :utc_datetime
    belongs_to :parent, PenguinMemories.Photos.Album, on_replace: :nilify
    has_many :children, PenguinMemories.Photos.Album, foreign_key: :parent_id
    has_many :ascendants, PenguinMemories.Photos.AlbumAscendant, foreign_key: :descendant_id
    has_many :descendants, PenguinMemories.Photos.AlbumAscendant, foreign_key: :ascendant_id
    many_to_many :photos, PenguinMemories.Photos.Photo, join_through: PhotoAlbum
    timestamps()
  end
end
