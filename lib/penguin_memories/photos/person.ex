defmodule PenguinMemories.Photos.Person do
  @moduledoc "An person"
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  import PenguinMemories.Photos.Private

  alias PenguinMemories.Photos.PersonAscendant
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.PhotoPerson

  @timestamps_opts [type: :utc_datetime]

  @type t :: %__MODULE__{
          id: integer() | nil,
          cover_photo_id: integer() | nil,
          cover_photo: Photo.t() | Ecto.Association.NotLoaded.t(),
          title: String.t() | nil,
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
          # children: list(t()) | Ecto.Association.NotLoaded.t(),
          ascendants: list(PersonAscendant.t()) | Ecto.Association.NotLoaded.t(),
          descendants: list(PersonAscendant.t()) | Ecto.Association.NotLoaded.t(),
          photos: list(Photo.t()) | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "pm_person" do
    belongs_to :cover_photo, Photo, on_replace: :nilify
    field :title, :string
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
    # has_many :children, PenguinMemories.Photos.Person, foreign_key: :parent_id
    has_many :ascendants, PenguinMemories.Photos.PersonAscendant, foreign_key: :descendant_id
    has_many :descendants, PenguinMemories.Photos.PersonAscendant, foreign_key: :ascendant_id
    many_to_many :photos, PenguinMemories.Photos.Photo, join_through: PhotoPerson
    timestamps()
  end

  @spec edit_changeset(t(), map()) :: Changeset.t()
  def edit_changeset(%__MODULE__{} = person, attrs) do
    person
    |> cast(attrs, [
      :cover_photo_id,
      :title,
      :called,
      :sort_name,
      :date_of_birth,
      :date_of_death,
      :home_id,
      :work_id,
      :father_id,
      :mother_id,
      :spouse_id,
      :description,
      :private_notes,
      :email,
      :revised
    ])
    |> validate_required([:title])
  end

  @spec update_changeset(object :: t(), attrs :: map(), assoc :: map(), enabled :: MapSet.t()) ::
          Changeset.t()
  def update_changeset(%__MODULE__{} = object, attrs, assoc, enabled) do
    object
    |> selective_cast(attrs, enabled, [:title, :revised])
    |> selective_validate_required(enabled, [:title])
    |> selective_put_assoc(assoc, enabled, [:mother, :father, :spouse, :work, :home, :cover_photo])
  end
end
