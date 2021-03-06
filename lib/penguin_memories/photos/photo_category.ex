defmodule PenguinMemories.Photos.PhotoCategory do
  @moduledoc """
  A relationship between a photo and an category.
  """

  use Ecto.Schema

  alias PenguinMemories.Photos.Category
  alias PenguinMemories.Photos.Photo

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: integer | nil,
          photo_id: integer | nil,
          photo: Photo.t() | Ecto.Association.NotLoaded.t() | nil,
          category_id: integer | nil,
          category: Category.t() | Ecto.Association.NotLoaded.t() | nil
        }

  schema "pm_photo_category" do
    belongs_to :photo, Photo
    belongs_to :category, Category
    timestamps()
  end
end
