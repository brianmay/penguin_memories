defmodule PenguinMemories.Photos.Album do
  @moduledoc "An album containing photos and subalbums"
  use Ecto.Schema

  alias PenguinMemories.Photos.AlbumAscendant
  alias PenguinMemories.Photos.AlbumParent
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.PhotoAlbum

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: integer() | nil,
          cover_photo_id: integer() | nil,
          cover_photo: Photo.t() | Ecto.Association.NotLoaded.t(),
          name: String.t() | nil,
          sort_name: String.t() | nil,
          description: String.t() | nil,
          private_notes: String.t() | nil,
          revised: DateTime.t() | nil,
          parent_id: integer() | nil,
          parent: t() | Ecto.Association.NotLoaded.t() | nil,
          children: list(t()) | Ecto.Association.NotLoaded.t(),
          album_parents: list(AlbumParent.t()) | Ecto.Association.NotLoaded.t(),
          parents: list(t()) | Ecto.Association.NotLoaded.t(),
          album_children: list(AlbumParent.t()) | Ecto.Association.NotLoaded.t(),
          ascendants: list(AlbumAscendant.t()) | Ecto.Association.NotLoaded.t(),
          descendants: list(AlbumAscendant.t()) | Ecto.Association.NotLoaded.t(),
          photos: list(Photo.t()) | Ecto.Association.NotLoaded.t(),
          reindex: boolean() | nil,
          photo_count: integer() | nil,
          child_count: integer() | nil,
          context_name: String.t() | nil,
          context_sort_name: String.t() | nil,
          context_cover_photo_id: integer() | nil,
          album_parent_albums: list(map()) | nil,
          album_parents_edit: list(t()) | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "pm_album" do
    belongs_to :cover_photo, Photo, on_replace: :nilify
    field :name, :string
    field :sort_name, :string
    field :description, :string
    field :private_notes, :string
    field :revised, :utc_datetime
    belongs_to :parent, PenguinMemories.Photos.Album, on_replace: :nilify
    has_many :children, PenguinMemories.Photos.Album, foreign_key: :parent_id

    # New many-to-many relationships with context
    has_many :album_parents, AlbumParent, foreign_key: :album_id
    has_many :parents, through: [:album_parents, :parent]
    has_many :album_children, AlbumParent, foreign_key: :parent_id
    has_many :children_via_context, through: [:album_children, :album]
    has_many :ascendants, PenguinMemories.Photos.AlbumAscendant, foreign_key: :descendant_id
    has_many :descendants, PenguinMemories.Photos.AlbumAscendant, foreign_key: :ascendant_id
    many_to_many :photos, PenguinMemories.Photos.Photo, join_through: PhotoAlbum
    field :reindex, :boolean
    field :photo_count, :integer, virtual: true
    field :child_count, :integer, virtual: true
    field :context_name, :string, virtual: true
    field :context_sort_name, :string, virtual: true
    field :context_cover_photo_id, :integer, virtual: true
    # For UI parent selection
    field :album_parent_albums, {:array, :map}, virtual: true
    # For edit form parent selection (contains Album structs)
    field :album_parents_edit, {:array, :map}, virtual: true
    # For storing operations during changeset validation
    field :album_parents_operations, :map, virtual: true
    timestamps()
  end
end
