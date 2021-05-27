defmodule PenguinMemories.Photos.Album do
  @moduledoc "An album containing photos and subalbums"
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  import PenguinMemories.Photos.Private

  alias PenguinMemories.Photos.AlbumAscendant
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.PhotoAlbum

  @timestamps_opts [type: :utc_datetime]

  @type t :: %__MODULE__{
          id: integer() | nil,
          cover_photo_id: integer() | nil,
          cover_photo: Photo.t() | Ecto.Association.NotLoaded.t(),
          title: String.t() | nil,
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
    field :title, :string
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

  @spec edit_changeset(object :: t(), attrs :: map(), assoc :: map()) :: Changeset.t()
  def edit_changeset(%__MODULE__{} = object, attrs, assoc) do
    object
    |> cast(attrs, [
      :title,
      :description,
      :private_notes,
      :revised
    ])
    |> validate_required([:title])
    |> put_all_assoc(assoc, [:parent, :cover_photo_id])
  end

  @spec update_changeset(object :: t(), attrs :: map(), assoc :: map(), enabled :: MapSet.t()) ::
          Changeset.t()
  def update_changeset(%__MODULE__{} = object, attrs, assoc, enabled) do
    object
    |> selective_cast(attrs, enabled, [:title, :revised])
    |> selective_validate_required(enabled, [:title])
    |> selective_put_assoc(assoc, enabled, [:parent, :cover_photo])
  end
end
