defmodule PenguinMemories.Photos.Category do
  @moduledoc "A category"
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  import PenguinMemories.Photos.Private
  alias PenguinMemories.Photos.CategoryAscendant
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.PhotoCategory

  @timestamps_opts [type: :utc_datetime]

  @type t :: %__MODULE__{
          id: integer() | nil,
          cover_photo_id: integer() | nil,
          cover_photo: Photo.t() | Ecto.Association.NotLoaded.t(),
          title: String.t() | nil,
          description: String.t() | nil,
          revised: DateTime.t() | nil,
          parent_id: integer() | nil,
          parent: t() | Ecto.Association.NotLoaded.t() | nil,
          children: list(t()) | Ecto.Association.NotLoaded.t(),
          ascendants: list(CategoryAscendant.t()) | Ecto.Association.NotLoaded.t(),
          descendants: list(CategoryAscendant.t()) | Ecto.Association.NotLoaded.t(),
          photos: list(Photo.t()) | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "pm_category" do
    belongs_to :cover_photo, Photo
    field :title, :string
    field :description, :string
    field :revised, :utc_datetime
    belongs_to :parent, PenguinMemories.Photos.Category
    has_many :children, PenguinMemories.Photos.Category, foreign_key: :parent_id
    has_many :ascendants, PenguinMemories.Photos.CategoryAscendant, foreign_key: :descendant_id
    has_many :descendants, PenguinMemories.Photos.CategoryAscendant, foreign_key: :ascendant_id
    many_to_many :photos, PenguinMemories.Photos.Photo, join_through: PhotoCategory
    timestamps()
  end

  @spec validate_revised(Changeset.t()) :: Changeset.t()
  defp validate_revised(%Changeset{data: %__MODULE__{}} = changeset) do
    validate_pair(changeset, :revised, :revised_utc_offset)
  end

  @spec edit_changeset(t(), map()) :: Changeset.t()
  def edit_changeset(%__MODULE__{} = category, attrs) do
    category
    |> cast(attrs, [
      :cover_photo_id,
      :title,
      :description,
      :revised,
      :parent_id
    ])
    |> validate_required([:title])
    |> validate_revised()
  end

  @spec update_changeset(t(), MapSet.t(), map()) :: Changeset.t()
  def update_changeset(%__MODULE__{} = category, enabled, attrs) do
    allowed_list = [:title, :parent_id, :revised]
    allowed = MapSet.new(allowed_list)
    enabled = MapSet.intersection(enabled, allowed)
    enabled_list = MapSet.to_list(enabled)
    required = MapSet.new([:title])
    required_list = MapSet.to_list(MapSet.intersection(enabled, required))

    category
    |> cast(attrs, enabled_list)
    |> validate_required(required_list)
  end
end
