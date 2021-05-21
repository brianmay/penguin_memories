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
    belongs_to :cover_photo, Photo, on_replace: :delete
    field :title, :string
    field :description, :string
    field :private_notes, :string
    field :revised, :utc_datetime
    belongs_to :parent, PenguinMemories.Photos.Album, on_replace: :delete
    has_many :children, PenguinMemories.Photos.Album, foreign_key: :parent_id
    has_many :ascendants, PenguinMemories.Photos.AlbumAscendant, foreign_key: :descendant_id
    has_many :descendants, PenguinMemories.Photos.AlbumAscendant, foreign_key: :ascendant_id
    many_to_many :photos, PenguinMemories.Photos.Photo, join_through: PhotoAlbum
    timestamps()
  end

  @spec validate_revised(Changeset.t()) :: Changeset.t()
  defp validate_revised(%Changeset{data: %__MODULE__{}} = changeset) do
    validate_pair(changeset, :revised, :revised_utc_offset)
  end

  @spec edit_changeset(t(), map()) :: Changeset.t()
  def edit_changeset(%__MODULE__{} = album, attrs) do
    album
    |> cast(attrs, [
      :title,
      :description,
      :private_notes,
      :revised
    ])
    |> cast_assoc(:cover_photo)
    |> cast_assoc(:parent)
    |> validate_required([:title])
    |> validate_revised()
  end

  @spec update_changeset(t(), MapSet.t(), map()) :: Changeset.t()
  def update_changeset(%__MODULE__{} = album, enabled, attrs) do
    allowed_list = [:title, :parent, :revised]
    allowed = MapSet.new(allowed_list)
    enabled = MapSet.intersection(enabled, allowed)
    enabled_list = MapSet.to_list(enabled)
    required = MapSet.new([:title])
    required_list = MapSet.to_list(MapSet.intersection(enabled, required))

    album
    |> cast(attrs, enabled_list)
    |> validate_required(required_list)
  end
end
