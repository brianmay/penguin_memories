defmodule PenguinMemories.Photos.Person do
  @moduledoc "An person"
  use Ecto.Schema

  alias PenguinMemories.Photos.PersonAscendant
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.PhotoPerson

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: integer() | nil,
          cover_photo_id: integer() | nil,
          cover_photo: Photo.t() | Ecto.Association.NotLoaded.t(),
          name: String.t() | nil,
          called: String.t() | nil,
          sort_name: String.t() | nil,
          date_of_birth: Date.t() | nil,
          date_of_death: Date.t() | nil,
          home_id: integer() | nil,
          home: t() | Ecto.Association.NotLoaded.t() | nil,
          work_id: integer() | nil,
          work: t() | Ecto.Association.NotLoaded.t() | nil,
          father_id: integer() | nil,
          father: t() | Ecto.Association.NotLoaded.t() | nil,
          mother_id: integer() | nil,
          mother: t() | Ecto.Association.NotLoaded.t() | nil,
          spouse_id: integer() | nil,
          spouse: t() | Ecto.Association.NotLoaded.t() | nil,
          description: String.t() | nil,
          private_notes: String.t() | nil,
          email: String.t() | nil,
          revised: DateTime.t() | nil,
          mother_of: list(t()) | Ecto.Association.NotLoaded.t(),
          father_of: list(t()) | Ecto.Association.NotLoaded.t(),
          ascendants: list(PersonAscendant.t()) | Ecto.Association.NotLoaded.t(),
          descendants: list(PersonAscendant.t()) | Ecto.Association.NotLoaded.t(),
          photos: list(Photo.t()) | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "pm_person" do
    belongs_to :cover_photo, Photo, on_replace: :nilify
    field :name, :string
    field :called, :string
    field :sort_name, :string
    field :date_of_birth, :date
    field :date_of_death, :date
    belongs_to :home, PenguinMemories.Photos.Place, on_replace: :nilify
    belongs_to :work, PenguinMemories.Photos.Place, on_replace: :nilify
    belongs_to :father, PenguinMemories.Photos.Person, on_replace: :nilify
    belongs_to :mother, PenguinMemories.Photos.Person, on_replace: :nilify
    belongs_to :spouse, PenguinMemories.Photos.Person, on_replace: :nilify
    field :description, :string
    field :private_notes, :string
    field :email, :string
    field :revised, :utc_datetime
    has_many :mother_of, PenguinMemories.Photos.Person, foreign_key: :mother_id
    has_many :father_of, PenguinMemories.Photos.Person, foreign_key: :father_id
    has_many :ascendants, PenguinMemories.Photos.PersonAscendant, foreign_key: :descendant_id
    has_many :descendants, PenguinMemories.Photos.PersonAscendant, foreign_key: :ascendant_id
    many_to_many :photos, PenguinMemories.Photos.Photo, join_through: PhotoPerson
    timestamps()
  end
end
