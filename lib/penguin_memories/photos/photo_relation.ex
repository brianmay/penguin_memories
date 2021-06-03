defmodule PenguinMemories.Photos.PhotoRelation do
  @moduledoc """
  A relationship between two photos.
  """
  use Ecto.Schema

  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.Relation

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          photo_id: Photo.t() | Ecto.Association.NotLoaded.t() | nil,
          relation_id: Relation.t() | Ecto.Association.NotLoaded.t() | nil,
          name: String.t() | nil
        }

  schema "pm_photo_relation" do
    belongs_to :photo, Photo
    belongs_to :relation, Relation
    field :name, :string
    timestamps()
  end
end
