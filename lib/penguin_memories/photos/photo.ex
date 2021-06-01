defmodule PenguinMemories.Photos.Photo do
  @moduledoc "A single photo"
  use Ecto.Schema

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
          filename: String.t() | nil,
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
          photo_persons: list(PhotoPerson.t()) | Ecto.Association.NotLoaded.t() | nil,
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
    field :filename, :string
    field :dir, :string
    field :rating, :float
    field :title, :string
    field :view, :string
    field :utc_offset, :integer
    field :related, :any, virtual: true
    has_many :files, File, on_replace: :delete

    many_to_many :albums, Album, join_through: PhotoAlbum, on_replace: :delete
    many_to_many :categorys, Category, join_through: PhotoCategory, on_replace: :delete
    belongs_to :place, Place, on_replace: :nilify
    belongs_to :photographer, Person, on_replace: :nilify
    has_many :photo_persons, PhotoPerson, on_replace: :delete

    has_many :photo_relations, PhotoRelation, foreign_key: :photo_id

    timestamps()
  end

  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = photo) do
    "#{photo.id}:#{photo.dir}/#{photo.filename}"
  end
end
