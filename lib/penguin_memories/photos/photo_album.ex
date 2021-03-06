defmodule PenguinMemories.Photos.PhotoPlace do
  @moduledoc """
  A relationship between a photo and an place.
  """

  use Ecto.Schema

  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.Place

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: integer | nil,
          photo_id: integer | nil,
          photo: Photo.t() | Ecto.Association.NotLoaded.t() | nil,
          place_id: integer | nil,
          place: Place.t() | Ecto.Association.NotLoaded.t() | nil
        }

  schema "pm_photo_place" do
    belongs_to :photo, Photo
    belongs_to :place, Place
    timestamps()
  end
end
