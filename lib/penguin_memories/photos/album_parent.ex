defmodule PenguinMemories.Photos.AlbumParent do
  @moduledoc "Many-to-many relationship between albums with context-specific presentation"
  use Ecto.Schema
  import Ecto.Changeset

  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.Photo

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: integer() | nil,
          album_id: integer() | nil,
          parent_id: integer() | nil,
          album: Album.t() | Ecto.Association.NotLoaded.t() | nil,
          parent: Album.t() | Ecto.Association.NotLoaded.t() | nil,
          context_name: String.t() | nil,
          context_sort_name: String.t() | nil,
          context_cover_photo_id: integer() | nil,
          context_cover_photo: Photo.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @enforce_keys []
  schema "pm_album_parent" do
    belongs_to :album, Album
    belongs_to :parent, Album
    field :context_name, :string
    field :context_sort_name, :string
    belongs_to :context_cover_photo, Photo

    timestamps()
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(album_parent, attrs) do
    album_parent
    |> cast(attrs, [
      :album_id,
      :parent_id,
      :context_name,
      :context_sort_name,
      :context_cover_photo_id
    ])
    |> validate_required([:album_id, :parent_id])
    |> unique_constraint([:album_id, :parent_id])
    |> foreign_key_constraint(:album_id)
    |> foreign_key_constraint(:parent_id)
    |> foreign_key_constraint(:context_cover_photo_id)
    |> validate_no_self_reference()
  end

  @spec validate_no_self_reference(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_no_self_reference(changeset) do
    album_id = get_field(changeset, :album_id)
    parent_id = get_field(changeset, :parent_id)

    if album_id && parent_id && album_id == parent_id do
      add_error(changeset, :parent_id, "cannot be the same as album")
    else
      changeset
    end
  end
end
