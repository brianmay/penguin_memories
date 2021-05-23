defmodule PenguinMemories.Photos.Photo do
  @moduledoc "A single photo"
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  import PenguinMemories.Photos.Private

  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.Category
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Person
  alias PenguinMemories.Photos.PhotoAlbum
  alias PenguinMemories.Photos.PhotoCategory
  alias PenguinMemories.Photos.PhotoPerson
  alias PenguinMemories.Photos.PhotoRelation
  alias PenguinMemories.Photos.Place
  alias PenguinMemories.Photos.Relation

  @timestamps_opts [type: :utc_datetime]

  @type t :: %__MODULE__{
          id: integer | nil,
          action: String.t() | nil,
          aperture: float | nil,
          camera_make: String.t() | nil,
          camera_model: String.t() | nil,
          ccd_width: integer | nil,
          private_notes: String.t() | nil,
          datetime: DateTime.t() | nil,
          description: String.t() | nil,
          exposure_time: float | nil,
          flash_used: boolean | nil,
          focal_length: integer | nil,
          focus_dist: float | nil,
          iso_equiv: integer | nil,
          metering_mode: String.t() | nil,
          name: String.t() | nil,
          dir: String.t() | nil,
          photographer_id: integer | nil,
          place_id: integer | nil,
          rating: float | nil,
          title: String.t() | nil,
          view: String.t() | nil,
          utc_offset: integer() | nil,
          files: list(File.t()) | Ecto.Association.NotLoaded.t() | nil,
          albums: list(Album.t()) | Ecto.Association.NotLoaded.t() | nil,
          categorys: list(Category.t()) | Ecto.Association.NotLoaded.t() | nil,
          place: Place.t() | Ecto.Association.NotLoaded.t() | nil,
          photographer: Person.t() | Ecto.Association.NotLoaded.t() | nil,
          photo_relations: list(PhotoRelation.t()) | Ecto.Association.NotLoaded.t() | nil,
          related: list(%{r: Relation.t(), pr: PhotoRelation.t()}) | nil
        }

  schema "pm_photo" do
    field :action, :string
    field :aperture, :float
    field :camera_make, :string
    field :camera_model, :string
    field :ccd_width, :integer
    field :private_notes, :string
    field :datetime, :utc_datetime
    field :description, :string
    field :exposure_time, :float
    field :flash_used, :boolean
    field :focal_length, :float
    field :focus_dist, :float
    field :iso_equiv, :integer
    field :metering_mode, :string
    field :name, :string
    field :dir, :string
    field :rating, :float
    field :title, :string
    field :view, :string
    field :utc_offset, :integer
    field :related, :any, virtual: true
    has_many :files, File, on_replace: :delete

    many_to_many :albums, Album, join_through: PhotoAlbum, on_replace: :delete
    many_to_many :categorys, Category, join_through: PhotoCategory, on_replace: :delete
    belongs_to :place, Place, on_replace: :delete
    belongs_to :photographer, Person, on_replace: :delete
    has_many :photo_persons, PhotoPerson, on_replace: :delete

    has_many :photo_relations, PhotoRelation, foreign_key: :photo_id

    timestamps()
  end

  @spec validate_datetime(Changeset.t()) :: Changeset.t()
  defp validate_datetime(%Changeset{data: %__MODULE__{}} = changeset) do
    validate_pair(changeset, :datetime, :utc_offset)
  end

  @spec validate_delete(Changeset.t()) :: Changeset.t()
  defp validate_delete(changeset) do
    id = get_field(changeset, :id)

    if get_change(changeset, :action) == "D" do
      case Query.can_delete?(id, PenguinMemories.Photos.Photo) do
        :yes -> changeset
        {:no, error} -> add_error(changeset, :action, error)
      end
    else
      changeset
    end
  end

  @spec validate_action(Changeset.t()) :: Changeset.t()
  defp validate_action(changeset) do
    validate_inclusion(changeset, :action, ["D", "R", "M", "auto", "90", "180", "270"])
  end

  @spec edit_changeset(t(), map()) :: Changeset.t()
  def edit_changeset(%__MODULE__{} = photo, attrs) do
    photo
    |> cast(attrs, [
      :title,
      :photographer_id,
      :view,
      :rating,
      :description,
      :datetime,
      :utc_offset,
      :action,
      :private_notes
    ])
    |> validate_action()
    |> validate_delete()
    |> validate_datetime()
    |> cast_assoc(:albums)
    |> cast_assoc(:categorys)
    |> cast_assoc(:place)
    |> cast_assoc(:photographer)
    |> cast_assoc(:photo_persons)
  end

  @spec update_changeset(t(), MapSet.t(), map()) :: Changeset.t()
  def update_changeset(%__MODULE__{} = photo, enabled, attrs) do
    allowed_list = [
      :title,
      :photographer,
      :place,
      :view,
      :rating,
      :description,
      :datetime,
      :utc_offset,
      :action
    ]

    allowed = MapSet.new(allowed_list)
    enabled = MapSet.intersection(enabled, allowed)
    enabled_list = MapSet.to_list(enabled)

    changeset =
      photo
      |> cast(attrs, enabled_list)
      |> validate_datetime()

    if MapSet.member?(enabled, :action) do
      validate_action(changeset)
    else
      changeset
    end
  end

  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = photo) do
    "#{photo.id}:#{photo.dir}/#{photo.name}"
  end
end
