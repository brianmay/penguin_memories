defmodule PenguinMemories.Photos.PhotoRelation do
  @moduledoc """
  A relationship between two photos.
  """
  use Ecto.Schema

  @timestamps_opts [type: :utc_datetime]

  schema "pm_photo_relation" do
    field :desc_1, :string
    field :desc_2, :string
    belongs_to :photo_1, PenguinMemories.Photos.Photo
    belongs_to :photo_2, PenguinMemories.Photos.Photo
    timestamps()
  end
end
