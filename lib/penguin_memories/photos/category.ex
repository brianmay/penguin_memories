defmodule PenguinMemories.Photos.Category do
  @moduledoc "A category"
  use Ecto.Schema

  alias PenguinMemories.Photos.CategoryAscendant
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.PhotoCategory

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
          ascendants: list(CategoryAscendant.t()) | Ecto.Association.NotLoaded.t(),
          descendants: list(CategoryAscendant.t()) | Ecto.Association.NotLoaded.t(),
          photos: list(Photo.t()) | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "pm_category" do
    belongs_to :cover_photo, Photo, on_replace: :nilify
    field :name, :string
    field :description, :string
    field :private_notes, :string
    field :revised, :utc_datetime
    belongs_to :parent, PenguinMemories.Photos.Category, on_replace: :nilify
    has_many :children, PenguinMemories.Photos.Category, foreign_key: :parent_id
    has_many :ascendants, PenguinMemories.Photos.CategoryAscendant, foreign_key: :descendant_id
    has_many :descendants, PenguinMemories.Photos.CategoryAscendant, foreign_key: :ascendant_id
    many_to_many :photos, PenguinMemories.Photos.Photo, join_through: PhotoCategory
    timestamps()
  end
end
