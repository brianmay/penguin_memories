defmodule PenguinMemories.Photos.PhotoRelation do
  @moduledoc """
  A relationship between two photos.
  """
  use Ecto.Schema

  alias PenguinMemories.Photos.Photo

  @timestamps_opts [type: :utc_datetime]

  @type t :: %__MODULE__{
          desc_1: String.t() | nil,
          desc_2: String.t() | nil,
          photo_1_id: integer | nil,
          photo_2_id: integer | nil,
          photo_1: Photo.t() | Ecto.Association.NotLoaded.t() | nil,
          photo_2: Photo.t() | Ecto.Association.NotLoaded.t() | nil
        }

  schema "pm_photo_relation" do
    field :desc_1, :string
    field :desc_2, :string
    belongs_to :photo_1, Photo
    belongs_to :photo_2, Photo
    timestamps()
  end
end
