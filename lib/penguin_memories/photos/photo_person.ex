defmodule PenguinMemories.Photos.PhotoPerson do
  @moduledoc """
  A relationship between a photo and an person.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias PenguinMemories.Photos.Person
  alias PenguinMemories.Photos.Photo

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: integer | nil,
          photo_id: integer | nil,
          photo: Photo.t() | Ecto.Association.NotLoaded.t() | nil,
          person_id: integer | nil,
          person: Person.t() | Ecto.Association.NotLoaded.t() | nil,
          position: integer() | nil
        }

  schema "pm_photo_person" do
    belongs_to :photo, Photo
    belongs_to :person, Person
    field :position, :integer
    timestamps()
  end

  def changeset(photo_person, attrs) do
    photo_person
    |> cast(attrs, [:photo_id, :person_id])
    |> validate_required([:photo_id, :person_id])
    |> foreign_key_constraint(:photo_id)
    |> foreign_key_constraint(:person_id)
  end
end
